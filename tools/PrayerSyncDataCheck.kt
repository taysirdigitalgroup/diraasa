import com.tdg.diraasa.PrayerSyncData
import org.json.JSONObject
import java.time.OffsetDateTime
fun main(){
 val bundle=JSONObject("""{"options":{"city":"Dakar","country":"Senegal","adjustments":{"Dhuhr":"١٠"}},"days":[{"timings":{"Fajr":"2026-10-27T05:00:00+03:00","Dhuhr":"2026-10-27T12:00:00+03:00","Maghrib":"2026-10-27T18:00:00+03:00","Isha":"2026-10-27T20:00:00+03:00"}}]}""")
 val events=PrayerSyncData.events(bundle,0)
 check(events.any{it["at"]==OffsetDateTime.parse("2026-10-27T11:55:00+03:00").toInstant().toEpochMilli()})
 check(events.any{it["at"]==OffsetDateTime.parse("2026-10-27T04:15:00+03:00").toInstant().toEpochMilli()})
 check(events.any{it["at"]==OffsetDateTime.parse("2026-10-27T18:00:00+03:00").toInstant().toEpochMilli()})
 check(PrayerSyncData.events(bundle,Long.MAX_VALUE).isEmpty())
 val a=bundle.getJSONObject("options");val b=JSONObject(a.toString()).put("adjustments",JSONObject().put("Dhuhr",20))
 check(PrayerSyncData.sameLocationAndMethod(a,b));b.put("city","Touba");check(!PrayerSyncData.sameLocationAndMethod(a,b))
 check(PrayerSyncData.number("-١٥",0)==-15)
 println("OK : calcul natif des appels, avances par défaut, chiffres arabes, fuseau ISO, échéance et identité des réglages serveur.")
}
