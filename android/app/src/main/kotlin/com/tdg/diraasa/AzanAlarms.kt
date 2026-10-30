package com.tdg.diraasa

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray
import java.io.File

object AzanAlarms {
    private fun prefs(c:Context)=c.getSharedPreferences("diraasa_azan_v1",Context.MODE_PRIVATE)
    fun exact(c:Context)=Build.VERSION.SDK_INT<31||(c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()
    fun notifications(c:Context)=(Build.VERSION.SDK_INT<24||(c.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager).areNotificationsEnabled())&&(Build.VERSION.SDK_INT<33||c.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED)
    fun active(c:Context)=prefs(c).getBoolean("enabled",false)&&exact(c)&&notifications(c)
    fun status(c:Context):Map<String,Any>{val p=prefs(c);val now=System.currentTimeMillis()
        val armed=JSONArray(p.getString("armed","[]"));val future=(0 until armed.length()).map{armed.getLong(it)}.filter{it>now}
        return mapOf("requested" to p.getBoolean("enabled",false),"background" to AlarmSupport.background(c),"exact" to exact(c),"notifications" to notifications(c),
            "enabled" to (active(c)&&AlarmSupport.background(c)&&future.isNotEmpty()),"scheduledCount" to future.size,"nextAt" to (future.minOrNull()?:0L),
            "lastError" to (p.getString("lastError","")?:""),"lastDelivery" to (p.getString("lastDelivery","")?:""),
            "audio" to (p.getString("audio","")?:""),"until" to p.getLong("until",0))}
    private fun pending(c:Context,index:Int,name:String="",at:Long=0,audio:String="",revision:String="")=PendingIntent.getBroadcast(c,86100+index,Intent(c,AzanReceiver::class.java).apply{action="com.tdg.diraasa.AZAN";putExtra("name",name);putExtra("at",at);putExtra("audio",audio);putExtra("revision",revision)},PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancel(c:Context){val manager=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for(i in 0 until 320){val old=PendingIntent.getBroadcast(c,86100+i,Intent(c,AzanReceiver::class.java).setAction("com.tdg.diraasa.AZAN"),PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
            if(old!=null){manager.cancel(old);old.cancel()}}
    }
    fun disable(c:Context){cancel(c);prefs(c).edit().putBoolean("enabled",false).putString("armed","[]").commit();if(AzanService.activeKind=="adhan")c.stopService(Intent(c,AzanService::class.java))}
    @Synchronized fun configure(c:Context,a:Map<*,*>):Map<String,Any>{
        check(exact(c)&&notifications(c)){"Autorisez les notifications et alarmes exactes"}
        val general=a["audio"]?.toString()?:"asset:audio/adhan_1.m4a"
        val audio=AlarmSupport.audio(c,if(general=="asset:audio/adhan_5.m4a")"asset:audio/adhan_1.m4a" else general)
        val fajrAudio=AlarmSupport.audio(c,a["fajrAudio"]?.toString()?:"asset:audio/adhan_5.m4a")
        val raw=JSONArray(a["events"] as? List<*>?:emptyList<Any>())
        val events=JSONArray();val now=System.currentTimeMillis()
        for(i in 0 until raw.length()){val e=raw.getJSONObject(i);if(e.getLong("at")>now){e.put("audio",if(e.optString("prayer")=="Fajr"||e.optString("name").startsWith("Fajr"))fajrAudio else audio);events.put(e)}}
        check(events.length() in 1..310){"Actualisez les horaires"}
        cancel(c)
        val p=prefs(c);check(p.edit().putString("events",events.toString()).putString("revision",java.util.UUID.randomUUID().toString()).putString("audio",audio).putBoolean("enabled",true).putLong("until",(0 until events.length()).maxOf{events.getJSONObject(it).getLong("at")}).commit())
        try{sync(c)}catch(e:Exception){p.edit().putString("armed","[]").putString("lastError",e.message?:"Programmation impossible").commit();throw e}
        return status(c)
    }
    @Synchronized fun sync(c:Context){
        val p=prefs(c)
        if(!p.getBoolean("enabled",false)||!exact(c)||!notifications(c)){
            cancel(c);p.edit().putString("armed","[]").commit();return
        }
        val rows=JSONArray(p.getString("events","[]"));val manager=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now=System.currentTimeMillis();val armed=JSONArray()
        val revision=p.getString("revision","")?:""
        // Rolling two-day horizon avoids OEM limits on hundreds of pending alarms.
        val future=(0 until rows.length()).map{rows.getJSONObject(it)}.filter{it.getLong("at")>now}.sortedBy{it.getLong("at")}.take(10)
        cancel(c)
        try{
            for((i,e) in future.withIndex()){
                val at=e.getLong("at")
                val show=PendingIntent.getActivity(c,86400,Intent(c,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                manager.setAlarmClock(AlarmManager.AlarmClockInfo(at,show),pending(c,i,e.getString("name"),at,e.optString("audio",p.getString("audio","")?:""),revision))
                armed.put(at)
            }
            check(p.edit().putString("armed",armed.toString()).putString("lastError","").commit())
        }catch(e:Exception){cancel(c);p.edit().putString("armed","[]").putString("lastError",e.message?:"Programmation impossible").commit();throw e}
    }
    @Synchronized fun claim(c:Context,intent:Intent):Boolean {
        val p=prefs(c);val at=intent.getLongExtra("at",0);val name=intent.getStringExtra("name")?:""
        val key="$at|$name"
        val allowed=active(c)&&AlarmDelivery.due(at)&&intent.getStringExtra("revision")==p.getString("revision",null)&&p.getString("lastClaim","")!=key
        if(allowed)check(p.edit().putString("lastClaim",key).putString("lastDelivery","Déclenché : $key").commit())
        else p.edit().putString("lastDelivery","Ignoré (périmé, remplacé ou désactivé) : $key").commit()
        return allowed
    }
    fun audio(c:Context)=prefs(c).getString("audio","")?:""
}
class AzanReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){
        val pending=goAsync()
        val wake=(context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager).newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK,"Diraasa:AlarmDelivery").apply{acquire(25000)}
        Thread{try{
            if(intent.action=="com.tdg.diraasa.AZAN"){
                if(AzanAlarms.claim(context,intent))AzanService.play(context,intent.getStringExtra("audio")?.takeIf{it.isNotBlank()}?:AzanAlarms.audio(context),intent.getStringExtra("name")?:"أذان")
                AzanAlarms.sync(context)
            }else{
                try{AzanAlarms.sync(context)}catch(e:Exception){android.util.Log.e("DiraasaAlarms","Azan rearm failed",e)}
                try{ZikrReminders.sync(context)}catch(e:Exception){android.util.Log.e("DiraasaAlarms","Reminder rearm failed",e)}
                PrayerSyncWorker.restoreLatest(context);PrayerSyncWorker.ensure(context)
            }
        }catch(e:Exception){android.util.Log.e("DiraasaAlarms","Alarm delivery failed",e)}finally{if(wake.isHeld)wake.release();pending.finish()}}.start()
    }
}
