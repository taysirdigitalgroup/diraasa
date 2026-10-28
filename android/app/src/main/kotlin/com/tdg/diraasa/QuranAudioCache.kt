package com.tdg.diraasa

import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** Small, temporary cache. No persistent/offline Quran download. */
data class QuranAudioKey(val chapter:Int,val verse:Int,val language:String){
    init{QuranAudioSource.url(chapter,verse,language)}
    val name:String get()="${language}_${QuranAudioSource.filename(chapter,verse)}"
    val url:String get()=QuranAudioSource.url(chapter,verse,language)
}
object QuranAudioWindow {
    fun around(key:QuranAudioKey):List<QuranAudioKey>{
        val first=if(key.chapter in setOf(1,9))1 else 0
        val last=QuranAudioSource.verseCount(key.chapter)
        return (maxOf(first,key.verse-3)..minOf(last,key.verse+3)).map{QuranAudioKey(key.chapter,it,key.language)}
    }
    fun priority(key:QuranAudioKey):List<QuranAudioKey>{
        val window=around(key).associateBy{it.verse}
        return listOfNotNull(window[key.verse])+ (1..3).mapNotNull{window[key.verse+it]} + (1..3).mapNotNull{window[key.verse-it]}
    }
}
class QuranAudioOffline:Exception("offline")
interface QuranAudioDownloader {
    fun download(key:QuranAudioKey,target:File,needed:()->Boolean)
    fun cancel()
}
class QuranAudioHttpDownloader(private val online:()->Boolean):QuranAudioDownloader {
    @Volatile private var connection:HttpURLConnection?=null
    override fun cancel(){connection?.disconnect()}
    override fun download(key:QuranAudioKey,target:File,needed:()->Boolean){
        if(!online())throw QuranAudioOffline()
        var address=key.url
        try{
            for(redirect in 0..3){
                check(needed()){"Cancelled"}
                val url=URL(address)
                require(url.protocol=="https" && url.host in setOf("raw.githubusercontent.com","media.githubusercontent.com","objects.githubusercontent.com"))
                val c=(url.openConnection() as HttpURLConnection).apply{
                    connectTimeout=10000;readTimeout=10000;instanceFollowRedirects=false
                    setRequestProperty("User-Agent","Diraasa-Quran-Audio/2.4.3")
                    setRequestProperty("Accept","audio/mpeg,application/octet-stream")
                };connection=c
                val code=c.responseCode
                if(code in listOf(301,302,303,307,308)){
                    val location=c.getHeaderField("Location")?:error("Redirect missing")
                    address=URL(url,location).toString();c.disconnect();continue
                }
                check(code==200){"HTTP $code"}
                require(c.contentLengthLong<=QuranAudioCache.MAX_FILE_BYTES){"Audio too large"}
                val type=c.contentType?.lowercase().orEmpty()
                require(!type.contains("text/html")&&!type.contains("json")){"Not an audio response"}
                val deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(30)
                var size=0L
                c.inputStream.use{input->target.outputStream().use{output->
                    val bytes=ByteArray(32768)
                    while(true){
                        check(needed()&&System.nanoTime()<deadline){"Cancelled or timeout"}
                        val count=input.read(bytes);if(count<0)break
                        size+=count;require(size<=QuranAudioCache.MAX_FILE_BYTES){"Audio too large"}
                        output.write(bytes,0,count)
                    }
                }}
                require(size>0 && (c.contentLengthLong<0 || c.contentLengthLong==size)){"Incomplete audio"}
                val head=target.inputStream().use{input->val bytes=ByteArray(256);val count=input.read(bytes);String(bytes,0,maxOf(0,count),Charsets.UTF_8).trimStart()}
                require(!head.startsWith("version https://git-lfs.github.com/")&&!head.startsWith("<html",true)&&!head.startsWith("<!DOCTYPE",true)){"Not an MP3"}
                return
            }
            error("Too many redirects")
        }finally{connection?.disconnect();connection=null}
    }
}

class QuranAudioCache(
    private val root:File,
    private val downloader:QuranAudioDownloader,
    private val validate:(File)->Unit,
    private val dispatch:(()->Unit)->Unit,
    private val changed:()->Unit={},
){
    companion object { const val MAX_FILE_BYTES=32L*1024*1024;const val MAX_CACHE_BYTES=128L*1024*1024 }
    private val lock=Any()
    private val executor=ThreadPoolExecutor(1,1,0L,TimeUnit.MILLISECONDS,LinkedBlockingQueue<Runnable>()){r->Thread(r,"Diraasa-Quran-cache").apply{isDaemon=true}}
    private var epoch=0L;private var delivered=-1L
    private var closed=false;private var accepting=false
    private var current:QuranAudioKey?=null;private var desired=emptyList<QuranAudioKey>()
    private var running:QuranAudioKey?=null
    private var ready:((File)->Unit)?=null;private var failed:((Exception)->Unit)?=null
    init{root.deleteRecursively();check(root.mkdirs()||root.isDirectory)}
    fun counts():Pair<Int,Int> = synchronized(lock){desired.count{File(root,it.name).isFile} to desired.size}
    fun request(key:QuranAudioKey,onReady:(File)->Unit,onError:(Exception)->Unit,languages:List<String> = listOf(key.language)){
        require(languages.distinct().size==languages.size && key.language in languages)
        synchronized(lock){
            check(!closed);epoch++;delivered=-1;accepting=true;current=key;desired=(listOf(key)+QuranAudioWindow.priority(key).flatMap{neighbor->languages.map{QuranAudioKey(key.chapter,neighbor.verse,it)}}).distinct();ready=onReady;failed=onError
            val currentReady=File(root,key.name).isFile
            if(running !in desired || (!currentReady && running!=key))downloader.cancel()
            evict();executor.queue.clear()
            val token=epoch
            if(currentReady)deliver(key,File(root,key.name))
            executor.execute{fill(token)}
        }
        dispatch{if(synchronized(lock){!closed})changed()}
    }
    private fun wanted(key:QuranAudioKey)=synchronized(lock){!closed&&accepting&&key in desired}
    private fun deliver(key:QuranAudioKey,file:File){
        val callback=synchronized(lock){
            if(!closed&&accepting&&key==current&&delivered!=epoch){delivered=epoch;ready}else null
        }
        if(callback!=null)dispatch{callback(file)}
    }
    private fun fill(token:Long){
        val work=synchronized(lock){if(token!=epoch||closed||!accepting)return;desired.toList()}
        for(key in work){
            if(synchronized(lock){closed||!accepting||token!=epoch})return
            val target=File(root,key.name)
            if(target.isFile){deliver(key,target);continue}
            val temporary=File(root,key.name+".part")
            synchronized(lock){running=key}
            try{
                downloader.download(key,temporary){wanted(key)}
                check(wanted(key)){"Cancelled"}
                validate(temporary)
                synchronized(lock){
                    if(!wanted(key))return@synchronized
                    check(temporary.renameTo(target)){"Cache write failed"}
                    evict();trimBudget();deliver(key,target)
                }
                dispatch{if(synchronized(lock){!closed})changed()}
            }catch(e:Exception){
                val callback=synchronized(lock){if(token==epoch&&accepting&&key==current&&delivered!=epoch){delivered=epoch;failed}else null}
                if(callback!=null)dispatch{callback(e)}
            }finally{
                temporary.delete()
                synchronized(lock){if(running==key)running=null;evict()}
            }
        }
    }
    private fun evict(){
        val keep=desired.map{it.name}.toSet();val part=running?.name?.plus(".part")
        root.listFiles()?.forEach{if(it.name !in keep && it.name!=part)it.delete()}
    }
    private fun trimBudget(){
        var bytes=root.listFiles()?.filter{it.extension=="mp3"}?.sumOf{it.length()}?:0L
        for(key in desired.asReversed()){
            if(bytes<=MAX_CACHE_BYTES)break
            if(key==current)continue
            val file=File(root,key.name);val size=file.length();if(file.delete())bytes-=size
        }
    }
    fun invalidate(key:QuranAudioKey){synchronized(lock){File(root,key.name).delete()}}
    fun pausePrefetch(){synchronized(lock){accepting=false;epoch++;ready=null;failed=null;executor.queue.clear();downloader.cancel()}}
    fun close(){synchronized(lock){closed=true;accepting=false;epoch++;ready=null;failed=null;executor.queue.clear();downloader.cancel()};executor.shutdownNow();root.deleteRecursively()}
}
