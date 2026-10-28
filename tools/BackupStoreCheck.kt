import com.tdg.diraasa.BackupStore
import org.json.JSONArray
import org.json.JSONObject
import java.nio.file.Files

fun main(){
    val directory=Files.createTempDirectory("diraasa-backup-store-check").toFile()
    try{
        val author=JSONObject().put("id",1).put("identity","auteur").put("name","Auteur").put("birth","").put("death","").put("alive",1).put("bio","سيرة").put("bio_format","").put("photo","")
        val note=JSONObject().put("id",4).put("title","دراسة").put("body","اللَّه — contenu").put("author","Auteur").put("kind","Cours").put("created",123L).put("updated",124L).put("pinned",1).put("author_id",1).put("body_format","")
        val reference=JSONObject().put("field","title").put("identity","دراسة").put("label","دراسة")
        val prefs=JSONObject().put("diraasa_preferences_v1",JSONObject().put("textSize",JSONObject().put("type","float").put("value",28.0)))
            .put("diraasa_devotion_v1",JSONObject().put("counterLibrary",JSONObject().put("type","string").put("value","""{"items":[{"id":"z1","text":"ذكر"}],"chains":[{"id":"w1"}]}""")))
        val data=JSONObject().put("createdAt",123L).put("tables",JSONObject().put("authors",JSONArray().put(author)).put("notes",JSONArray().put(note)).put("note_references",JSONArray().put(reference))).put("preferences",prefs).put("attachments",JSONObject())
        prefs.getJSONObject("diraasa_devotion_v1").put("prayerAudio",JSONObject().put("type","string").put("value",JSONObject.quote("/old/private/audio.m4a")))
        note.put("body","{  \"a\": 1 }")
        val remapped=BackupStore.remapData(data,mapOf("/old/private/audio.m4a" to "/new/private/audio.m4a"))
        val savedAudio=remapped.getJSONObject("preferences").getJSONObject("diraasa_devotion_v1").getJSONObject("prayerAudio").getString("value")
        check(org.json.JSONTokener(savedAudio).nextValue()=="/new/private/audio.m4a")
        check(remapped.getJSONObject("tables").getJSONArray("notes").getJSONObject(0).getString("body")=="{  \"a\": 1 }")
        note.put("body","/old/private/audio.m4a")
        val unchanged=BackupStore.remapData(data,mapOf("/old/private/audio.m4a" to "/new/private/audio.m4a"))
        check(unchanged.getJSONObject("tables").getJSONArray("notes").getJSONObject(0).getString("body")=="/old/private/audio.m4a")
        note.put("body","اللَّه — contenu")
        BackupStore.validate(data,directory)
        val summary=BackupStore.summary(data)
        check(summary["notes"]==1 && summary["authors"]==1 && summary["themes"]==1 && summary["azkar"]==1 && summary["wird"]==1)
        fun rejects(label:String,change:(JSONObject)->Unit){val copy=JSONObject(data.toString());change(copy);var rejected=false
            try{BackupStore.validate(copy,directory)}catch(_:Exception){rejected=true};check(rejected){label}}
        rejects("missing author"){it.getJSONObject("tables").getJSONArray("notes").getJSONObject(0).put("author_id",99)}
        rejects("unknown columns"){it.getJSONObject("tables").getJSONArray("notes").getJSONObject(0).put("extra",true)}
        rejects("foreign preferences"){it.getJSONObject("preferences").put("FirebaseAuth",JSONObject())}
        rejects("missing attachment"){it.getJSONObject("attachments").put("old/path","media/"+"0".repeat(64)+".img")}
        check(note.getString("body")=="اللَّه — contenu")
        println("OK: backup schema, identities, references, preference allowlist, summary, missing attachment rejection")
    }finally{directory.deleteRecursively()}
}
