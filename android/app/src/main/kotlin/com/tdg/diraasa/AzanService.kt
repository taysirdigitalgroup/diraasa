package com.tdg.diraasa

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

class AzanService:Service(){
    private var player:MediaPlayer?=null
    private fun reportFailure(message:String){
        android.util.Log.e("DiraasaAlarms",message)
        if(activeKind=="adhan")getSharedPreferences("diraasa_azan_v1",Context.MODE_PRIVATE).edit().putString("lastError",message).commit()
    }
    private val prepareTimeout=Runnable{if(!prepared){reportFailure("Audio de l’alarme indisponible ou préparation trop longue");stopSelf()}}

    private var prepared=false
    private val startupWake by lazy {(getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"Diraasa:AlarmAudioPrepare").apply{setReferenceCounted(false)}}
    private val handler=android.os.Handler(android.os.Looper.getMainLooper())
    companion object{
        private var instance:AzanService?=null
        private var previewId=""
        fun previewStatus():Map<String,Any> = mapOf("audio" to previewId,"playing" to (activeKind=="preview" && instance?.player?.isPlaying==true))
        fun togglePreview(id:String):Boolean {
            val service=instance?:return false
            val player=service.player?:return false
            if(activeKind!="preview"||previewId!=id)return false
            if(!service.prepared)return true
            if(player.isPlaying)player.pause() else player.start()
            return true
        }
        @Volatile var activeKind=""
            private set
        fun play(c:Context,path:String,name:String,reminder:Boolean=false,preview:Boolean=false,previewId:String=""){val intent=Intent(c,AzanService::class.java).putExtra("previewId",previewId).putExtra("audio",path).putExtra("name",name).putExtra("reminder",reminder).putExtra("kind",if(preview)"preview" else if(reminder)"reminder" else "adhan");if(Build.VERSION.SDK_INT>=26)c.startForegroundService(intent)else c.startService(intent)}
    }
    override fun onBind(intent:Intent?):IBinder?=null
    @Suppress("DEPRECATION")
    override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int{
        if(intent?.action=="STOP"){stopSelf();return START_NOT_STICKY}
        startupWake.acquire(30000)
        QuranAudio.pauseForAlarm()
        instance=this
        previewId=intent?.getStringExtra("previewId")?:""
        activeKind=intent?.getStringExtra("kind")?:"adhan"
        val channel="diraasa_azan"
        if(Build.VERSION.SDK_INT>=26)(getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(NotificationChannel(channel,"Diraasa · Azan",NotificationManager.IMPORTANCE_LOW).apply{setSound(null,null)})
        val stop=PendingIntent.getService(this,8521,Intent(this,AzanService::class.java).setAction("STOP"),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open=PendingIntent.getActivity(this,8522,Intent(this,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder=if(Build.VERSION.SDK_INT>=26)Notification.Builder(this,channel)else Notification.Builder(this)
        val notification=builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle(intent?.getStringExtra("name")?:"Diraasa · أذان")
            .setContentText("Diraasa · إيقاف / Arrêter / Stop").setContentIntent(open).setOngoing(true).addAction(android.R.drawable.ic_media_pause,"إيقاف · Stop",stop).build()
        if(Build.VERSION.SDK_INT>=29)startForeground(8520,notification,android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)else startForeground(8520,notification)
        handler.removeCallbacksAndMessages(null)
        prepared=false
        handler.postDelayed(prepareTimeout,20000)
        player?.release()
        try{
            player=MediaPlayer().apply{
                setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                setWakeMode(this@AzanService,PowerManager.PARTIAL_WAKE_LOCK)
                setDataSource(intent?.getStringExtra("audio")?:"")
                isLooping=intent?.getBooleanExtra("reminder",false)==true
                setOnPreparedListener{prepared=true;handler.removeCallbacks(prepareTimeout);it.start();if(activeKind=="adhan")getSharedPreferences("diraasa_azan_v1",Context.MODE_PRIVATE).edit().putString("lastError","").apply();if(startupWake.isHeld)startupWake.release()};setOnCompletionListener{stopSelf()};setOnErrorListener{_,what,extra->reportFailure("Erreur audio alarme : $what/$extra");stopSelf();true};prepareAsync()
            }
            if(intent?.getBooleanExtra("reminder",false)==true)handler.postDelayed({stopSelf()},30000)
        }catch(e:Exception){reportFailure(e.message?:"Erreur audio alarme");stopSelf()}
        return START_NOT_STICKY
    }
    @Suppress("DEPRECATION")
    override fun onDestroy(){if(startupWake.isHeld)startupWake.release();instance=null;previewId="";activeKind="";handler.removeCallbacksAndMessages(null);player?.release();player=null;stopForeground(true);super.onDestroy()}
}
