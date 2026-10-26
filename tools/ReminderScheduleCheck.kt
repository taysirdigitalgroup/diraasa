import com.tdg.diraasa.ZikrReminders
import org.json.JSONObject
import org.json.JSONArray
import java.time.Instant
import java.util.TimeZone

fun main(){
    TimeZone.setDefault(TimeZone.getTimeZone("Africa/Dakar"))
    val row=JSONObject().put("hour",8).put("minute",30).put("weekdays",JSONArray(listOf(1,5)))
    check(ZikrReminders.next(row,Instant.parse("2026-10-26T07:00:00Z").toEpochMilli())==Instant.parse("2026-10-26T08:30:00Z").toEpochMilli())
    check(ZikrReminders.next(row,Instant.parse("2026-10-26T09:00:00Z").toEpochMilli())==Instant.parse("2026-10-30T08:30:00Z").toEpochMilli())
    check(ZikrReminders.next(row,Instant.parse("2026-10-30T09:00:00Z").toEpochMilli())==Instant.parse("2026-11-02T08:30:00Z").toEpochMilli())
    check(ZikrReminders.next(JSONObject().put("hour",8).put("minute",30).put("weekdays",JSONArray()),0)==null)
    TimeZone.setDefault(TimeZone.getTimeZone("Europe/Paris"))
    check(ZikrReminders.next(row,Instant.parse("2026-10-26T06:00:00Z").toEpochMilli())==Instant.parse("2026-10-26T07:30:00Z").toEpochMilli())
    println("OK : planification native, jour courant, jours sélectionnés, semaine suivante, changement de fuseau et jours vides.")
}
