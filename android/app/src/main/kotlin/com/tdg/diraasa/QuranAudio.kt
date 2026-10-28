package com.tdg.diraasa

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build

/** Foreground reader only: MainActivity.onStop releases playback. No new SDK. */
class QuranAudio(private val context:Context){
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
    private var chapter=1;private var language="ar";private var generation=0
    private var pendingSeek:Int?=null
    private var state="stopped";private var error="";private var wantsPlay=false
    private val attributes=AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
    private val listener=AudioManager.OnAudioFocusChangeListener{change->if(change!=AudioManager.AUDIOFOCUS_GAIN){ownsFocus=false;pause()}}
    @Suppress("DEPRECATION")
    private fun acquire():Boolean {
        if(ownsFocus)return true
        val result=if(Build.VERSION.SDK_INT>=26){
            val request=AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(attributes).setOnAudioFocusChangeListener(listener).build();focus=request;manager.requestAudioFocus(request)
        }else manager.requestAudioFocus(listener,AudioManager.STREAM_MUSIC,AudioManager.AUDIOFOCUS_GAIN)
        ownsFocus=result==AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return ownsFocus
    }
    @Suppress("DEPRECATION")
    private fun abandon(){if(Build.VERSION.SDK_INT>=26)focus?.let{manager.abandonAudioFocusRequest(it)} else manager.abandonAudioFocus(listener);ownsFocus=false;focus=null}
    fun status():Map<String,Any>{val ready=state in setOf("playing","paused")
        return mapOf("state" to state,"chapter" to chapter,"verse" to (queue.getOrNull(index)?:-1),"language" to language,
            "position" to (pendingSeek?:if(ready)try{player?.currentPosition?:0}catch(_:Exception){0} else 0),
            "duration" to (if(ready)try{player?.duration?.coerceAtLeast(0)?:0}catch(_:Exception){0} else 0),"error" to error)
    }
    fun start(args:Map<*,*>):Map<String,Any>{
        val newChapter=(args["chapter"] as? Number)?.toInt()?:0
        val lang=args["language"]?.toString()?:""
        val input=(args["verses"] as? List<*>)?.map{(it as? Number)?.toInt()?:-1}?:emptyList()
        require(newChapter in 1..114 && lang in setOf("ar","fr") && input.size in 1..287)
        require(input.all{it in 0..286 && (it!=0 || newChapter !in setOf(1,9))})
        stop();active=this;chapter=newChapter;language=lang;queue=input;index=0;wantsPlay=true;error=""
        if(AzanService.activeKind in setOf("adhan","reminder")||!acquire()){state="error";error="focus";return status()}
        load();return status()
    }
    private fun filename()=QuranAudioSource.filename(chapter,queue[index])
    private fun load(){
        val token=++generation;pendingSeek=null;handler.removeCallbacksAndMessages(null);player?.release();player=null;state="loading"
        val media=MediaPlayer();player=media
        try{
            media.setAudioAttributes(attributes)
            media.setOnSeekCompleteListener{if(token==generation)pendingSeek=null}
            media.setOnPreparedListener{p->if(token==generation){handler.removeCallbacksAndMessages(null);if(wantsPlay&&acquire()){p.start();state="playing"}else state="paused"}}
            media.setOnCompletionListener{if(token==generation){if(index+1<queue.size){index++;load()}else{state="completed";active=null;wantsPlay=false;player?.release();player=null;abandon()}}}
            media.setOnErrorListener{_,_,_->if(token==generation)failed();true}
            media.setDataSource(QuranAudioSource.url(chapter,queue[index],language))
            media.prepareAsync()
            handler.postDelayed({if(token==generation&&state=="loading")failed()},25000)
        }catch(_:Exception){if(token==generation)failed()}
    }
    private fun failed(){active=null;pendingSeek=null;generation++;handler.removeCallbacksAndMessages(null);state="error";error=filename();wantsPlay=false;player?.release();player=null;abandon()}
    fun pause():Map<String,Any>{wantsPlay=false;if(state=="playing"){player?.pause();state="paused"};return status()}
    fun resume():Map<String,Any>{
        if(state=="paused" && AzanService.activeKind !in setOf("adhan","reminder") && acquire()){wantsPlay=true;player?.start();state="playing"}
        return status()
    }
    fun seek(position:Int):Map<String,Any>{if(state in setOf("playing","paused")){pendingSeek=position.coerceIn(0,player?.duration?.coerceAtLeast(0)?:0);player?.seekTo(pendingSeek!!)};return status()}
    fun stop():Map<String,Any>{if(active===this)active=null;pendingSeek=null;generation++;handler.removeCallbacksAndMessages(null);wantsPlay=false;state="stopped";player?.release();player=null;queue=emptyList();index=0;abandon();return status()}
}
