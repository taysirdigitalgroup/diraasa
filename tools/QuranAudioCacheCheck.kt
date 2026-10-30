import com.tdg.diraasa.*
import java.io.File
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.ConcurrentHashMap

fun main(){
    val dir=Files.createTempDirectory("diraasa-cache-check").toFile()
    fun waitFor(predicate:()->Boolean){val end=System.nanoTime()+TimeUnit.SECONDS.toNanos(5)
        while(!predicate()){check(System.nanoTime()<end){"Cache wait timed out"};Thread.sleep(5)}}
    val calls=ConcurrentHashMap<QuranAudioKey,Int>()
    val downloader=object:QuranAudioDownloader{
        override fun cancel(){}
        override fun download(key:QuranAudioKey,target:File,needed:()->Boolean){
            check(needed());calls.merge(key,1){a,b->a+b};target.writeText(key.name)
        }
    }
    val cache=QuranAudioCache(File(dir,"window"),downloader,validate={check(it.length()>0)},dispatch={it()})
    fun request(key:QuranAudioKey){val done=CountDownLatch(1)
        cache.request(key,{check(it.readText()==key.name);done.countDown()},{throw it})
        check(done.await(5,TimeUnit.SECONDS))}
    try{
        val center=QuranAudioKey(2,10,"ar")
        check(QuranAudioWindow.around(center).map{it.verse}==(10..12).toList())
        check(QuranAudioWindow.around(QuranAudioKey(1,1,"en")).map{it.verse}==(1..3).toList())
        check(QuranAudioWindow.around(QuranAudioKey(9,1,"fr")).none{it.verse==0})
        check(QuranAudioWindow.around(QuranAudioKey(2,0,"fr")).map{it.verse}==(0..2).toList())
        request(center);waitFor{cache.counts()==(3 to 3)}
        check(calls.size==3)
        request(QuranAudioKey(2,11,"ar"));waitFor{cache.counts()==(3 to 3)}
        check(calls[QuranAudioKey(2,11,"ar")]==1){"Cached current verse fetched again"}
        check(!File(dir,"window/ar_002010.mp3").exists())
        check(File(dir,"window/ar_002013.mp3").isFile)
        cache.invalidate(QuranAudioKey(2,11,"ar"))
        request(QuranAudioKey(2,11,"ar"));waitFor{cache.counts()==(3 to 3)}
        check(calls[QuranAudioKey(2,11,"ar")]==2){"Invalidated file not fetched again"}
        request(QuranAudioKey(2,11,"en"));waitFor{cache.counts()==(3 to 3)}
        check(File(dir,"window").listFiles()!!.all{it.name.startsWith("en_")})
        cache.pausePrefetch()
        request(QuranAudioKey(2,12,"en"));waitFor{cache.counts()==(3 to 3)}
        check(calls[QuranAudioKey(2,12,"en")]==1)
        check(File(dir,"window").listFiles()!!.filter{it.extension=="mp3"}.size<=3)
        val mixedReady=CountDownLatch(1)
        val mixed=listOf("ar","fr","en")
        cache.request(QuranAudioKey(2,10,"ar"),{mixedReady.countDown()},{throw it},mixed)
        check(mixedReady.await(5,TimeUnit.SECONDS));waitFor{cache.counts()==(6 to 6)}
        val previousCalls=calls.toMap()
        val frenchReady=CountDownLatch(1)
        cache.request(QuranAudioKey(2,10,"fr"),{frenchReady.countDown()},{throw it},mixed)
        check(frenchReady.await(5,TimeUnit.SECONDS));waitFor{cache.counts()==(6 to 6)}
        check(calls.toMap()==previousCalls){"Switching a mixed language refetched cached files"}
        val entered=CountDownLatch(1);val release=CountDownLatch(1)
        val running=java.util.concurrent.atomic.AtomicBoolean(false)
        val stale=java.util.concurrent.atomic.AtomicInteger(0)
        val switched=CountDownLatch(1)
        val slow=object:QuranAudioDownloader{
            override fun cancel(){if(running.get())release.countDown()}
            override fun download(key:QuranAudioKey,target:File,needed:()->Boolean){
                if(key.verse==20){running.set(true);entered.countDown();check(release.await(5,TimeUnit.SECONDS));running.set(false)}
                check(needed());target.writeText(key.name)
            }
        }
        val concurrent=QuranAudioCache(File(dir,"concurrent"),slow,{check(it.length()>0)},{it()})
        try{
            concurrent.request(QuranAudioKey(2,20,"ar"),{stale.incrementAndGet()},{stale.incrementAndGet()})
            check(entered.await(5,TimeUnit.SECONDS))
            concurrent.request(QuranAudioKey(2,30,"ar"),{check(it.name=="ar_002030.mp3");switched.countDown()},{throw it})
            check(switched.await(5,TimeUnit.SECONDS))
            waitFor{concurrent.counts()==(3 to 3)}
            check(stale.get()==0){"Stale request delivered"}
        }finally{release.countDown();concurrent.close()}
        println("OK: current +2 / mixed current +1, boundaries/basmala, sliding eviction, reuse, language isolation, stop/restart")
    }finally{cache.close();dir.deleteRecursively()}
}
