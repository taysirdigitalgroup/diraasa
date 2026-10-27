package com.tdg.diraasa

import android.content.Context
import androidx.work.*
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit

object PrayerSyncData {
    val names=listOf("Fajr","Dhuhr","Asr","Maghrib","Isha")
    val defaults=mapOf("Fajr" to 45,"Dhuhr" to 15,"Asr" to 15,"Maghrib" to 0,"Isha" to 15)
    fun number(value:String,fallback:Int):Int=value.map{c->val n=Character.digit(c,10);if(n>=0)('0'.code+n).toChar()else c}.joinToString("").trim().toIntOrNull()?:fallback
    fun epoch(value:String):Long?=try{OffsetDateTime.parse(value).toInstant().toEpochMilli()}catch(_:Exception){null}
    fun end(days:JSONArray):Long{var end=0L;for(i in 0 until days.length()){val at=epoch(days.getJSONObject(i).optJSONObject("timings")?.optString("Isha")?:"")?:0;end=maxOf(end,at)};return end}
    fun events(bundle:JSONObject,now:Long=System.currentTimeMillis()):List<Map<String,Any>>{
        val options=bundle.optJSONObject("options")?:JSONObject();val offsets=options.optJSONObject("adjustments")?:JSONObject();val leads=bundle.optJSONObject("azanLeads")?:JSONObject();val days=bundle.optJSONArray("days")?:JSONArray()
        val active=options.optJSONArray("activePrayers");val allowed=if(active==null)names.toSet() else (0 until active.length()).map{active.getString(it)}.toSet()
        val events=mutableListOf<Map<String,Any>>()
        for(i in 0 until days.length())for(name in names){
            if(name !in allowed)continue
            val base=epoch(days.getJSONObject(i).optJSONObject("timings")?.optString(name)?:"")?:continue
            val at=base+(number(offsets.optString(name),0).coerceIn(-120,120)-number(leads.optString(name),defaults.getValue(name)).coerceIn(0,180))*60000L
            if(at>now)events.add(mapOf("at" to at,"name" to "$name · أذان"))
        }
        return events.sortedBy{it["at"] as Long}
    }
    fun sameLocationAndMethod(a:JSONObject,b:JSONObject):Boolean{
        if(a.optBoolean("coordinates")!=b.optBoolean("coordinates")||a.optInt("method",3)!=b.optInt("method",3)||a.optBoolean("hanafi")!=b.optBoolean("hanafi"))return false
        return if(a.optBoolean("coordinates"))a.optString("latitude").replace(',','.').toDoubleOrNull()==b.optString("latitude").replace(',','.').toDoubleOrNull()&&a.optString("longitude").replace(',','.').toDoubleOrNull()==b.optString("longitude").replace(',','.').toDoubleOrNull()
        else a.optString("city").trim().equals(b.optString("city").trim(),true)&&a.optString("country").trim().equals(b.optString("country").trim(),true)
    }
}
class PrayerSyncWorker(context:Context,params:WorkerParameters):Worker(context,params){
    companion object{
        val lock=Any()
        private var fetching=false
        private fun prefs(c:Context)=c.getSharedPreferences("diraasa_devotion_v1",Context.MODE_PRIVATE)
        fun restoreAlarms(c:Context,data:JSONObject){
            val wanted=data.optBoolean("adhanWanted",AzanAlarms.status(c)["requested"]==true)
            val rows=PrayerSyncData.events(data)
            if(!wanted||rows.isEmpty()){AzanAlarms.disable(c);return}
            if(AzanAlarms.exact(c)&&AzanAlarms.notifications(c)&&AlarmSupport.background(c))AzanAlarms.configure(c,mapOf("audio" to (data.optJSONObject("options")?.optString("audio","asset:audio/adhan_1.m4a")?:"asset:audio/adhan_1.m4a"),"events" to rows))
            else AzanAlarms.disable(c)
        }
        private fun migrated(c:Context):JSONObject?=synchronized(lock){
            val raw=prefs(c).getString("prayerBundle",null)?:return@synchronized null
            val data=try{JSONObject(raw)}catch(_:Exception){return@synchronized null}
            if(!data.has("adhanWanted")){
                data.put("adhanWanted",AzanAlarms.status(c)["requested"]==true)
                check(prefs(c).edit().putString("prayerBundle",data.toString()).commit())
            }
            data
        }
        fun restoreLatest(c:Context){synchronized(lock){val data=migrated(c)?:return;restoreAlarms(c,data)}}
        fun ensure(c:Context){
            val data=migrated(c)?:return;val days=data.optJSONArray("days")?:return
            if(days.length()==0)return
            val constraints=Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            val manager=WorkManager.getInstance(c)
            val periodic=PeriodicWorkRequest.Builder(PrayerSyncWorker::class.java,12,TimeUnit.HOURS).setConstraints(constraints).setBackoffCriteria(BackoffPolicy.EXPONENTIAL,15,TimeUnit.MINUTES).build()
            manager.enqueueUniquePeriodicWork("diraasa_prayer_sync",ExistingPeriodicWorkPolicy.KEEP,periodic)
            val end=PrayerSyncData.end(days);if(end<=0)return
            val delay=maxOf(0L,end-System.currentTimeMillis()-TimeUnit.HOURS.toMillis(12))
            val request=OneTimeWorkRequest.Builder(PrayerSyncWorker::class.java).setConstraints(constraints).setInitialDelay(delay,TimeUnit.MILLISECONDS).setBackoffCriteria(BackoffPolicy.EXPONENTIAL,15,TimeUnit.MINUTES).build()
            manager.enqueueUniqueWork("diraasa_prayer_expiry_$end",ExistingWorkPolicy.KEEP,request)
        }
        fun writeBundle(c:Context,text:String){
            synchronized(lock){
                val next=JSONObject(text);val oldRaw=prefs(c).getString("prayerBundle",null)
                if(oldRaw!=null){
                    val old=JSONObject(oldRaw)
                    if(old.optLong("syncedAt")>next.optLong("syncedAt")&&PrayerSyncData.sameLocationAndMethod(old.optJSONObject("options")?:JSONObject(),next.optJSONObject("options")?:JSONObject())){
                        next.put("days",old.optJSONArray("days")?:JSONArray());next.put("syncedAt",old.optLong("syncedAt"))
                    }
                }
                check(prefs(c).edit().putString("prayerBundle",next.toString()).commit())
            }
            ensure(c)
        }
    }
    override fun doWork():Result{
        synchronized(lock){if(fetching)return Result.retry();fetching=true}
        try{
            val snapshot=prefs(applicationContext).getString("prayerBundle",null)?:return Result.success()
            val data=JSONObject(snapshot);val oldDays=data.optJSONArray("days")?:return Result.success()
            if(oldDays.length()==0)return Result.success()
            synchronized(lock){if(prefs(applicationContext).getString("prayerBundle",null)!=snapshot)return Result.retry();restoreAlarms(applicationContext,data)}
            if(PrayerSyncData.end(oldDays)>System.currentTimeMillis()+TimeUnit.HOURS.toMillis(24))return Result.success()
            val options=data.optJSONObject("options")?:return Result.success()
            val zone=try{ZoneId.of(oldDays.getJSONObject(oldDays.length()-1).getJSONObject("meta").getString("timezone"))}catch(_:Exception){ZoneId.systemDefault()}
            val now=LocalDate.now(zone);val days=JSONArray()
            for(month in listOf(now.withDayOfMonth(1),now.withDayOfMonth(1).plusMonths(1))){
                if(isStopped)return Result.retry()
                val query=linkedMapOf("method" to options.optInt("method",3).toString(),"school" to if(options.optBoolean("hanafi"))"1" else "0","iso8601" to "true")
                val coordinates=options.optBoolean("coordinates")
                if(coordinates){query["latitude"]=options.getString("latitude").trim().replace(',','.');query["longitude"]=options.getString("longitude").trim().replace(',','.')}
                else{query["city"]=options.getString("city").trim();query["country"]=options.getString("country").trim()}
                val encoded=query.entries.joinToString("&"){URLEncoder.encode(it.key,"UTF-8")+"="+URLEncoder.encode(it.value,"UTF-8")}
                val connection=URL("https://api.aladhan.com/v1/${if(coordinates)"calendar" else "calendarByCity"}/${month.year}/${month.monthValue}?$encoded").openConnection() as HttpURLConnection
                try{
                    connection.connectTimeout=15000;connection.readTimeout=20000;connection.setRequestProperty("User-Agent","Diraasa/2.2.1 (com.tdg.diraasa)")
                    check(connection.responseCode==200)
                    val text=connection.inputStream.bufferedReader(Charsets.UTF_8).use{it.readText()};check(text.length<4*1024*1024)
                    val result=JSONObject(text);check(result.getInt("code")==200);val entries=result.getJSONArray("data");check(entries.length() in 28..31)
                    for(i in 0 until entries.length()){
                        val entry=entries.getJSONObject(i);val timings=entry.getJSONObject("timings")
                        check(PrayerSyncData.names.all{PrayerSyncData.epoch(timings.optString(it))!=null});days.put(entry)
                    }
                }finally{connection.disconnect()}
            }
            synchronized(lock){
                if(isStopped)return Result.retry()
                val latest=JSONObject(prefs(applicationContext).getString("prayerBundle",null)?:return Result.success())
                if(!PrayerSyncData.sameLocationAndMethod(options,latest.optJSONObject("options")?:JSONObject()))return Result.retry()
                val wanted=latest.optBoolean("adhanWanted",AzanAlarms.status(applicationContext)["requested"]==true)
                latest.put("days",days).put("syncedAt",System.currentTimeMillis()).put("adhanWanted",wanted)
                check(prefs(applicationContext).edit().putString("prayerBundle",latest.toString()).commit())
                restoreAlarms(applicationContext,latest)
            }

            ensure(applicationContext)
            return Result.success()
        }catch(_:Exception){return Result.retry()}
        finally{synchronized(lock){fetching=false}}
    }
}
