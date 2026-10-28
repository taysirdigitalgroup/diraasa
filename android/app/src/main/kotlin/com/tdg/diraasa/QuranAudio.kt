package com.tdg.diraasa

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.os.Build
import java.io.File

/** Reader-only player with a temporary 3-behind/current/3-ahead MP3 cache. */
class QuranAudio(private val context:Context,private val changed:(Map<String,Any>)->Unit={}) {
    companion object {
        private var active:QuranAudio?=null
        fun pauseForAlarm(){active?.let{it.pause();it.abandon()}}
    }
    private val handler=android.os.Handler(android.os.Looper.getMainLooper())
    private var player:MediaPlayer?=null
    private val manager=context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focus:AudioFocusRequest?=null
    private var ownsFocus=false
    private var queue=listOf<Int>();private var index=0
    private var chapter=1;private var sequence=QuranAudioSequence.parse("ar");private val language:String get()=sequence.language;private var generation=0
    private var pendingSeek:Int?=null
    private var revision=0L;private var session="";private var continuous=false
    private var state="stopped";private var error="";private var wantsPlay=false
    private var timeout:Runnable?=null
    private val attributes=AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
    private val listener=AudioManager.OnAudioFocusChangeListener{change->if(change!=AudioManager.AUDIOFOCUS_GAIN){ownsFocus=false;pause()}}
    private val cache by lazy {
        val parent=File(context.cacheDir,"quran_audio_window").apply{mkdirs()}
        parent.listFiles()?.forEach{it.deleteRecursively()}
        QuranAudioCache(File(parent,java.util.UUID.randomUUID().toString()),QuranAudioHttpDownloader{online()},
            validate={file->val probe=MediaMetadataRetriever()
                try{probe.setDataSource(file.path)
                    require((probe.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()?:0)>0){"Invalid audio"}
                    require(probe.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE) in setOf("audio/mpeg","audio/mp3","audio/x-mpeg")){"Not an MP3"}
                }finally{probe.release()}
            },dispatch={action->handler.post{action()}},changed={publish()})
    }
    private fun publish(){revision++;changed(status())}
    private fun clearTimeout(){timeout?.let{handler.removeCallbacks(it)};timeout=null}
    @Suppress("DEPRECATION")
    private fun acquire():Boolean {
        if(ownsFocus)return true
        val result=if(Build.VERSION.SDK_INT>=26){
            val request=AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(attributes).setOnAudioFocusChangeListener(listener).build()
            focus=request;manager.requestAudioFocus(request)
        }else manager.requestAudioFocus(listener,AudioManager.STREAM_MUSIC,AudioManager.AUDIOFOCUS_GAIN)
        ownsFocus=result==AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return ownsFocus
    }
    @Suppress("DEPRECATION")
    private fun abandon(){if(Build.VERSION.SDK_INT>=26)focus?.let{manager.abandonAudioFocusRequest(it)} else manager.abandonAudioFocus(listener);ownsFocus=false;focus=null}
    fun status():Map<String,Any>{
        val ready=state in setOf("playing","paused");val counts=cache.counts()
        return mapOf("revision" to revision,"session" to session,"state" to state,"chapter" to chapter,
            "verse" to (queue.getOrNull(index)?:-1),"language" to language,
            "mode" to sequence.languages.joinToString("-"),"continuous" to continuous,
            "position" to (pendingSeek?:if(ready)try{player?.currentPosition?:0}catch(_:Exception){0} else 0),
            "duration" to (if(ready)try{player?.duration?.coerceAtLeast(0)?:0}catch(_:Exception){0} else 0),
            "cacheReady" to counts.first,"cacheTarget" to counts.second,"error" to error)
    }
    fun start(args:Map<*,*>):Map<String,Any>{
        val newChapter=(args["chapter"] as? Number)?.toInt()?:0;val lang=args["language"]?.toString()?:""
        val newSequence=QuranAudioSequence.parse(lang)
        val input=(args["verses"] as? List<*>)?.map{(it as? Number)?.toInt()?:-1}?:emptyList()
        require(newChapter in 1..114&&input.size in 1..287)
        input.forEach{QuranAudioSource.filename(newChapter,it)}
        require(input.distinct().size==input.size&&input.zipWithNext().all{(a,b)->b==a+1})
        stop();session=args["session"]?.toString()?:"";active=this;chapter=newChapter;sequence=newSequence;continuous=args["continuous"]==true;queue=input;index=0;wantsPlay=true;error=""
        if(AzanService.activeKind in setOf("adhan","reminder")||!acquire()){state="error";error="focus";publish();return status()}
        load();return status()
    }
    private fun filename()=QuranAudioSource.filename(chapter,queue[index])
    private fun online():Boolean {
        val connectivity=context.getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        val network=connectivity.activeNetwork?:return false
        return connectivity.getNetworkCapabilities(network)?.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)==true
    }
    private fun load(){
        val token=++generation;pendingSeek=null;clearTimeout();player?.release();player=null;state="loading";publish()
        timeout=Runnable{if(token==generation&&state=="loading")failed()}.also{handler.postDelayed(it,25000)}
        cache.request(QuranAudioKey(chapter,queue[index],language),
            onReady={file->if(token==generation)prepare(file,token)},
            onError={e->if(token==generation)failed(if(e is QuranAudioOffline)"offline" else null)},
            languages=sequence.languages)
    }
    private fun prepare(file:File,token:Int){
        val media=MediaPlayer();player=media
        try{
            media.setAudioAttributes(attributes)
            media.setWakeMode(context,android.os.PowerManager.PARTIAL_WAKE_LOCK)
            media.setOnSeekCompleteListener{if(token==generation){pendingSeek=null;publish()}}
            media.setOnPreparedListener{p->if(token==generation){clearTimeout()
                if(p.duration<=0){failed();return@setOnPreparedListener}
                if(wantsPlay&&acquire()){p.start();state="playing"}else state="paused";publish()
            }}
            media.setOnCompletionListener{if(token==generation){
                if(!sequence.advance()){load()}else if(index+1<queue.size){index++;load()}else{
                    state="completed";active=null;wantsPlay=false;player?.release();player=null;cache.pausePrefetch();abandon();publish()
                }
            }}
            media.setOnErrorListener{_,_,_->if(token==generation)failed();true}
            media.setDataSource(file.path);media.prepareAsync()
        }catch(_:Exception){if(token==generation)failed()}
    }
    private fun failed(reason:String?=null){active=null;pendingSeek=null;generation++;clearTimeout();state="error";error=reason?:filename();wantsPlay=false;player?.release();player=null;cache.pausePrefetch();cache.invalidate(QuranAudioKey(chapter,queue[index],language));abandon();publish()}
    fun pause():Map<String,Any>{wantsPlay=false;if(state=="playing"){player?.pause();state="paused"};publish();return status()}
    fun resume():Map<String,Any>{if(state=="paused"&&AzanService.activeKind !in setOf("adhan","reminder")&&acquire()){wantsPlay=true;player?.start();state="playing"};publish();return status()}
    fun seek(position:Int):Map<String,Any>{if(state in setOf("playing","paused")){pendingSeek=position.coerceIn(0,player?.duration?.coerceAtLeast(0)?:0);player?.seekTo(pendingSeek!!)};return status()}
    fun stopIfSession(expected:String):Map<String,Any> = if(expected==session)stop() else status()
    fun stop():Map<String,Any>{if(active===this)active=null;pendingSeek=null;generation++;clearTimeout();wantsPlay=false;state="stopped";player?.release();player=null;queue=emptyList();index=0;cache.pausePrefetch();abandon();publish();return status()}
    fun close(){stop();cache.close();handler.removeCallbacksAndMessages(null)}
}
