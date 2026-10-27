package com.tdg.diraasa

import android.app.*
import android.content.*
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object ZikrReminders {
    private fun prefs(c:Context)=c.getSharedPreferences("diraasa_reminders_v1",Context.MODE_PRIVATE)
    private fun pending(c:Context,id:String)=PendingIntent.getBroadcast(c,8530,Intent(c,ZikrReminderReceiver::class.java).apply{
        action="com.tdg.diraasa.ZIKR";data=Uri.parse("diraasa://reminder/"+Uri.encode(id));putExtra("id",id)
    },PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun configure(c:Context,rows:List<*>):Boolean {
        val input=JSONArray(rows);check(input.length()<=100){"100 rappels maximum"};var enabled=false
        for(i in 0 until input.length())if(input.getJSONObject(i).optBoolean("enabled"))enabled=true
        if(enabled)check(AzanAlarms.exact(c)&&AzanAlarms.notifications(c)){"Autorisez notifications et alarmes exactes"}
        val old=JSONArray(prefs(c).getString("rows","[]"));val manager=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for(i in 0 until old.length()){val id=old.getJSONObject(i).getString("id");manager.cancel(pending(c,id));(c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id,8532)}
        check(prefs(c).edit().putString("rows",input.toString()).commit())
        sync(c);return true
    }
    fun next(row:JSONObject,now:Long=System.currentTimeMillis()):Long?{
        val weekdays=row.optJSONArray("weekdays")?:return null
        val days=(0 until weekdays.length()).map{weekdays.getInt(it)}.toSet()
        if(days.isEmpty())return null
        val hour=row.getInt("hour");val minute=row.getInt("minute")
        require(hour in 0..23&&minute in 0..59)
        for(offset in 0..7){
            val calendar=Calendar.getInstance().apply{timeInMillis=now;add(Calendar.DAY_OF_YEAR,offset);set(Calendar.HOUR_OF_DAY,hour);set(Calendar.MINUTE,minute);set(Calendar.SECOND,0);set(Calendar.MILLISECOND,0)}
            val day=(calendar.get(Calendar.DAY_OF_WEEK)+5)%7+1
            if(day in days&&calendar.timeInMillis>now)return calendar.timeInMillis
        }
        return null
    }
    @Synchronized fun sync(c:Context){
        if(!AzanAlarms.exact(c)||!AzanAlarms.notifications(c))return
        val rows=JSONArray(prefs(c).getString("rows","[]"));val manager=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for(i in 0 until rows.length()){val row=rows.getJSONObject(i);if(!row.optBoolean("enabled"))continue
            val at=next(row)?:continue
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending(c,row.getString("id")))
        }
    }
    @Suppress("DEPRECATION")
    fun fire(c:Context,id:String){
        val rows=JSONArray(prefs(c).getString("rows","[]"));var row:JSONObject?=null
        for(i in 0 until rows.length())if(rows.getJSONObject(i).optString("id")==id)row=rows.getJSONObject(i)
        val reminder=row?:return
        // The persisted library is authoritative: deleted/disabled targets never notify.
        val library=JSONObject(c.getSharedPreferences("diraasa_devotion_v1",Context.MODE_PRIVATE).getString("counterLibrary","{}")?:"{}")
        val live=library.optJSONArray("reminders")?:JSONArray();var allowed=false
        for(i in 0 until live.length())if(live.getJSONObject(i).optString("id")==id&&live.getJSONObject(i).optBoolean("enabled"))allowed=true
        if(!allowed||!reminder.optBoolean("enabled")||!AzanAlarms.notifications(c))return
        val manager=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel="diraasa_zikr_reminders_v2"
        if(Build.VERSION.SDK_INT>=26)manager.createNotificationChannel(NotificationChannel(channel,"Diraasa · أذكار",NotificationManager.IMPORTANCE_DEFAULT).apply{setSound(null,null)})
        val open=PendingIntent.getActivity(c,8531,Intent(c,MainActivity::class.java).apply{
            flags=Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data=Uri.parse("diraasa://counter/"+Uri.encode(id));putExtra("devotionTarget",reminder.getString("targetId"));putExtra("devotionChain",reminder.optBoolean("chain"))
        },PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder=if(Build.VERSION.SDK_INT>=26)Notification.Builder(c,channel)else Notification.Builder(c)
        val notification=builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle("Diraasa · أذكار")
            .setContentText(reminder.optString("label").take(120)).setAutoCancel(true).setContentIntent(open).build()
        manager.notify(id,8532,notification)
        try{AzanService.play(c,AlarmSupport.audio(c,reminder.optString("audio","asset:audio/reminder.ogg")),"Diraasa · أذكار",true)}finally{sync(c)}
    }
}
class ZikrReminderReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){val pending=goAsync();Thread{
        try{
            if(intent.action=="com.tdg.diraasa.TEST"){
                if(kotlin.math.abs(System.currentTimeMillis()-intent.getLongExtra("at",0))<60000)AzanService.play(context,intent.getStringExtra("audio")?:"","Diraasa · Test",true)
            }else ZikrReminders.fire(context,intent.getStringExtra("id")?:"")
        }catch(_:Exception){}finally{pending.finish()}
    }.start()}
}
