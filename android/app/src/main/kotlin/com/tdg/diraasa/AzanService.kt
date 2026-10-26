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
    companion object{
        fun play(c:Context,path:String,name:String){val intent=Intent(c,AzanService::class.java).putExtra("audio",path).putExtra("name",name);if(Build.VERSION.SDK_INT>=26)c.startForegroundService(intent)else c.startService(intent)}
    }
    override fun onBind(intent:Intent?):IBinder?=null
    @Suppress("DEPRECATION")
    override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int{
        if(intent?.action=="STOP"){stopSelf();return START_NOT_STICKY}
        val channel="diraasa_azan"
        if(Build.VERSION.SDK_INT>=26)(getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(NotificationChannel(channel,"Diraasa · Azan",NotificationManager.IMPORTANCE_LOW).apply{setSound(null,null)})
        val stop=PendingIntent.getService(this,8521,Intent(this,AzanService::class.java).setAction("STOP"),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open=PendingIntent.getActivity(this,8522,Intent(this,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder=if(Build.VERSION.SDK_INT>=26)Notification.Builder(this,channel)else Notification.Builder(this)
        val notification=builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle(intent?.getStringExtra("name")?:"Diraasa · أذان")
            .setContentText("Diraasa · إيقاف / Arrêter / Stop").setContentIntent(open).setOngoing(true).addAction(android.R.drawable.ic_media_pause,"إيقاف · Stop",stop).build()
        if(Build.VERSION.SDK_INT>=29)startForeground(8520,notification,android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)else startForeground(8520,notification)
        player?.release()
        try{
            player=MediaPlayer().apply{
                setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                setWakeMode(this@AzanService,PowerManager.PARTIAL_WAKE_LOCK)
                setDataSource(intent?.getStringExtra("audio")?:"")
                setOnPreparedListener{it.start()};setOnCompletionListener{stopSelf()};setOnErrorListener{_,_,_->stopSelf();true};prepareAsync()
            }
        }catch(_:Exception){stopSelf()}
        return START_NOT_STICKY
    }
    @Suppress("DEPRECATION")
    override fun onDestroy(){player?.release();player=null;stopForeground(true);super.onDestroy()}
}
