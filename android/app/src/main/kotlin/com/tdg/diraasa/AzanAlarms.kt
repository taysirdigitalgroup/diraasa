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
    fun status(c:Context):Map<String,Any>{val p=prefs(c);return mapOf("background" to AlarmSupport.background(c),"exact" to exact(c),"notifications" to notifications(c),"enabled" to (p.getBoolean("enabled",false)&&exact(c)&&notifications(c)&&p.getLong("until",0)>System.currentTimeMillis()),"audio" to (p.getString("audio","")?:""),"until" to p.getLong("until",0))}
    private fun pending(c:Context,index:Int,name:String="",at:Long=0)=PendingIntent.getBroadcast(c,86100+index,Intent(c,AzanReceiver::class.java).apply{action="com.tdg.diraasa.AZAN";putExtra("name",name);putExtra("at",at)},PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancel(c:Context){val manager=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager;for(i in 0 until 320)manager.cancel(pending(c,i))}
    fun disable(c:Context){cancel(c);prefs(c).edit().putBoolean("enabled",false).commit();c.stopService(Intent(c,AzanService::class.java))}
    @Synchronized fun configure(c:Context,a:Map<*,*>):Map<String,Any>{
        check(exact(c)&&notifications(c)){"Autorisez les notifications et alarmes exactes"}
        val audio=AlarmSupport.audio(c,a["audio"]?.toString()?:"asset:audio/adhan_1.m4a")
        val raw=JSONArray(a["events"] as? List<*>?:emptyList<Any>())
        val events=JSONArray();val now=System.currentTimeMillis()
        for(i in 0 until raw.length()){val e=raw.getJSONObject(i);if(e.getLong("at")>now)events.put(e)}
        check(events.length() in 1..310){"Actualisez les horaires"}
        cancel(c)
        val p=prefs(c);check(p.edit().putString("events",events.toString()).putString("audio",audio).putBoolean("enabled",true).putLong("until",events.getJSONObject(events.length()-1).getLong("at")).commit())
        try{sync(c)}catch(e:Exception){disable(c);throw e}
        return status(c)
    }
    @Synchronized fun sync(c:Context){
        val p=prefs(c);if(!p.getBoolean("enabled",false)||!exact(c)||!notifications(c))return
        val rows=JSONArray(p.getString("events","[]"));val manager=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now=System.currentTimeMillis()
        for(i in 0 until rows.length()){val e=rows.getJSONObject(i);if(e.getLong("at")>now)manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,e.getLong("at"),pending(c,i,e.getString("name"),e.getLong("at")))}
    }
    fun audio(c:Context)=prefs(c).getString("audio","")?:""
}
class AzanReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){
        if(intent.action=="com.tdg.diraasa.AZAN"){
            if(kotlin.math.abs(System.currentTimeMillis()-intent.getLongExtra("at",0))>5*60*1000)return
            if(AzanAlarms.active(context))try{AzanService.play(context,AzanAlarms.audio(context),intent.getStringExtra("name")?:"أذان")}catch(_:Exception){}
        }else{val pending=goAsync();Thread{try{AzanAlarms.sync(context);ZikrReminders.sync(context)}catch(_:Exception){}finally{pending.finish()}}.start()}
    }
}
