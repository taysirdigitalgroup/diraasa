package com.tdg.diraasa

import android.app.*
import android.content.*
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.*

/** Playback belongs to this service, never to an Activity or a Flutter page. */
class QuranAudioService:Service() {
    companion object {
        private const val ID=8530
        private const val CHANNEL="diraasa_quran_audio"
        private var instance:QuranAudioService?=null
        private var owner:Any?=null
        private var observer:((Map<String,Any>)->Unit)?=null
        private var last:Map<String,Any> = mapOf("state" to "stopped","session" to "","verse" to -1)
        private val pending=mutableMapOf<String,Pair<(Map<String,Any>)->Unit,(Exception)->Unit>>()
        fun observe(token:Any,callback:(Map<String,Any>)->Unit){owner=token;observer=callback}
        fun detach(token:Any){if(owner===token){owner=null;observer=null}}
        fun status():Map<String,Any> = instance?.audio?.status()?:last
        fun start(c:Context,args:Map<*,*>,done:(Map<String,Any>)->Unit,failed:(Exception)->Unit){
            // Validate before launching a foreground service.
            val chapter=(args["chapter"] as? Number)?.toInt()?:0
            val mode=args["language"]?.toString()?:""
            QuranAudioSequence.parse(mode)
            val verses=(args["verses"] as? List<*>)?.map{(it as? Number)?.toInt()?:-1}?:emptyList()
            require(verses.size in 1..287)
            verses.forEach{QuranAudioSource.filename(chapter,it)}
            require(verses.distinct().size==verses.size&&verses.zipWithNext().all{(a,b)->b==a+1})
            val request=java.util.UUID.randomUUID().toString()
            pending[request]=done to failed
            val intent=Intent(c,QuranAudioService::class.java).setAction("START")
                .putExtra("request",request).putExtra("chapter",chapter).putExtra("language",mode)
                .putExtra("verses",verses.toIntArray()).putExtra("session",args["session"]?.toString()?:"")
                .putExtra("continuous",args["continuous"]==true)
            try {if(Build.VERSION.SDK_INT>=26)c.startForegroundService(intent)else c.startService(intent)}
            catch(e:Exception){pending.remove(request);failed(e)}
        }
        fun command(method:String,args:Map<*,*>):Map<String,Any> {
            val service=instance?:return last
            return when(method){
                "quranAudioStatus"->service.audio.status()
                "quranAudioPause"->service.audio.pause()
                "quranAudioResume"->service.audio.resume()
                "quranAudioSeek"->service.audio.seek((args["position"] as? Number)?.toInt()?:0)
                "quranAudioStop"->service.audio.stopIfSession(args["session"]?.toString()?:"")
                else->throw IllegalArgumentException("Commande audio inconnue")
            }
        }
    }
    // Android 13+ reads artwork from MediaSession; older versions use largeIcon.
    private val artwork by lazy {
        val icon=applicationInfo.loadIcon(packageManager)
        android.graphics.Bitmap.createBitmap(512,512,android.graphics.Bitmap.Config.ARGB_8888).also{bitmap->
            icon.setBounds(0,0,bitmap.width,bitmap.height)
            icon.draw(android.graphics.Canvas(bitmap))
        }
    }
    private lateinit var audio:QuranAudio
    private lateinit var media:MediaSession
    private val handler=Handler(Looper.getMainLooper())
    private val wake by lazy {(getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"Diraasa:QuranPlayback").apply{setReferenceCounted(false)}}
    private val tick=object:Runnable{override fun run(){if(!closing){onStatus(audio.status());handler.postDelayed(this,30000)}}}
    private var closing=false
    private var foreground=false
    private var lastStart=0
    private var terminal:Runnable?=null
    private val noisy=object:BroadcastReceiver(){override fun onReceive(c:Context?,i:Intent?){audio.pause()}}
    override fun onBind(intent:Intent?):IBinder?=null
    override fun onCreate(){
        super.onCreate();instance=this
        if(Build.VERSION.SDK_INT>=26)(getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(
            NotificationChannel(CHANNEL,"Diraasa · Coran / القرآن / Quran",NotificationManager.IMPORTANCE_LOW).apply{setSound(null,null);setShowBadge(false)})
        audio=QuranAudio(applicationContext){onStatus(it)}
        media=MediaSession(this,"Diraasa-Quran").apply{
            setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS)
            setCallback(object:MediaSession.Callback(){
                override fun onPlay(){audio.resume()}
                override fun onPause(){audio.pause()}
                override fun onStop(){audio.stop()}
                override fun onSeekTo(pos:Long){audio.seek(pos.coerceIn(0,Int.MAX_VALUE.toLong()).toInt())}
            },handler)
            isActive=true
        }
        handler.postDelayed(tick,30000)
        val filter=IntentFilter(android.media.AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if(Build.VERSION.SDK_INT>=33)registerReceiver(noisy,filter,Context.RECEIVER_NOT_EXPORTED)else registerReceiver(noisy,filter)
    }
    override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int {
        lastStart=startId
        terminal?.let{handler.removeCallbacks(it)};terminal=null
        try {
            if(intent?.action=="START"){
                // Start foreground before acquiring focus (Android 15+ requirement).
                enterForeground(notification(mapOf("state" to "loading")))
                val args=mapOf("chapter" to intent.getIntExtra("chapter",0),"language" to (intent.getStringExtra("language")?:""),
                    "verses" to (intent.getIntArrayExtra("verses")?.toList()?:emptyList<Int>()),"session" to (intent.getStringExtra("session")?:""),
                    "continuous" to intent.getBooleanExtra("continuous",false))
                val value=audio.start(args)
                pending.remove(intent.getStringExtra("request").orEmpty())?.first?.invoke(value)
            }else when(intent?.action){
                "PAUSE"->audio.pause()
                "PLAY"->audio.resume()
                "STOP"->audio.stop()
                else->if(!foreground)stopSelf(startId)
            }
        }catch(e:Exception){
            pending.remove(intent?.getStringExtra("request").orEmpty())?.second?.invoke(e)
            audio.stop();stopSelf(startId)
        }
        return START_NOT_STICKY
    }
    private fun action(name:String,code:Int)=PendingIntent.getService(this,code,Intent(this,QuranAudioService::class.java).setAction(name),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun open()=PendingIntent.getActivity(this,8533,Intent(this,MainActivity::class.java).putExtra("quranAudioOpen",true)
        .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    @Suppress("DEPRECATION")
    private fun notification(value:Map<String,Any>):Notification {
        val playing=value["state"]=="playing"||value["state"]=="loading"
        val reference=if(value["verse"]==0)"${value["chapter"]}: البسملة" else "${value["chapter"]?:""}:${value["verse"]?:""}"
        val builder=if(Build.VERSION.SDK_INT>=26)Notification.Builder(this,CHANNEL)else Notification.Builder(this)
        return builder.setSmallIcon(R.drawable.ic_launcher_monochrome).setLargeIcon(artwork).setContentTitle("Diraasa · القرآن · Hafs")
            .setContentText("$reference · ${value["language"]?.toString()?.uppercase()?:"…"}")
            .setContentIntent(open()).setVisibility(Notification.VISIBILITY_PUBLIC).setCategory(Notification.CATEGORY_TRANSPORT)
            .setOnlyAlertOnce(true).setOngoing(playing).setShowWhen(false)
            .addAction(if(playing)android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,if(playing)"Pause · إيقاف مؤقت" else "Lecture · تشغيل",action(if(playing)"PAUSE" else "PLAY",8531))
            .addAction(android.R.drawable.ic_menu_close_clear_cancel,"Arrêter · Stop · إيقاف",action("STOP",8532))
            .setDeleteIntent(action("STOP",8532)).setStyle(Notification.MediaStyle().setMediaSession(media.sessionToken).setShowActionsInCompactView(0,1)).build()
    }
    private fun enterForeground(notification:Notification){
        if(Build.VERSION.SDK_INT>=29)startForeground(ID,notification,android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)else startForeground(ID,notification)
        foreground=true
    }
    private fun onStatus(value:Map<String,Any>){
        last=value
        if(closing)return
        observer?.invoke(value)
        val state=value["state"]?.toString()?:"stopped"
        if(state in setOf("playing","loading"))wake.acquire(120000)else if(wake.isHeld)wake.release()
        val position=(value["position"] as? Number)?.toLong()?:0L
        val duration=(value["duration"] as? Number)?.toLong()?:0L
        val playback=when(state){"playing"->PlaybackState.STATE_PLAYING;"paused"->PlaybackState.STATE_PAUSED;"loading"->PlaybackState.STATE_BUFFERING;"completed"->PlaybackState.STATE_STOPPED;"error"->PlaybackState.STATE_ERROR;else->PlaybackState.STATE_STOPPED}
        media.setMetadata(MediaMetadata.Builder()
            .putBitmap(MediaMetadata.METADATA_KEY_ART,artwork)
            .putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART,artwork)
            .putBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON,artwork)
            .putString(MediaMetadata.METADATA_KEY_TITLE,"Hafs · ${value["chapter"]}:${value["verse"]} · ${value["language"]}")
            .putString(MediaMetadata.METADATA_KEY_ARTIST,"Diraasa · القرآن الكريم").putLong(MediaMetadata.METADATA_KEY_DURATION,duration).build())
        media.setPlaybackState(PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_STOP or PlaybackState.ACTION_SEEK_TO)
            .setState(playback,position,if(state=="playing")1f else 0f,SystemClock.elapsedRealtime()).build())
        if(state in setOf("playing","loading","paused")){
            terminal?.let{handler.removeCallbacks(it)};terminal=null
            if(foreground)(getSystemService(NOTIFICATION_SERVICE) as NotificationManager).notify(ID,notification(value))
        }else{
            terminal?.let{handler.removeCallbacks(it)}
            val id=lastStart
            terminal=Runnable{stopSelf(id)}.also{handler.post(it)}
        }
    }
    // Swiping the Activity away must not interrupt an ongoing recitation.
    override fun onTaskRemoved(rootIntent:Intent?){super.onTaskRemoved(rootIntent)}
    @Suppress("DEPRECATION")
    override fun onDestroy(){
        closing=true;handler.removeCallbacksAndMessages(null)
        try{unregisterReceiver(noisy)}catch(_:Exception){}
        audio.close();if(wake.isHeld)wake.release();media.isActive=false;media.release()
        if(instance===this)instance=null
        stopForeground(true);foreground=false
        super.onDestroy()
    }
}
