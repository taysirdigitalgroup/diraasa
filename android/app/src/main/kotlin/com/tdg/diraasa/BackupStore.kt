package com.tdg.diraasa

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.io.File
import java.util.UUID

/** Runs on MainActivity's data executor. Journal bridges SQLite and preferences. */
object BackupStore {
    val lock=Any()
    @Volatile var recoveryPending=false
        private set
    private val tables=linkedMapOf(
        "authors" to setOf("id","identity","name","birth","death","alive","bio","bio_format","photo"),
        "note_references" to setOf("field","identity","label"),
        "notes" to setOf("id","title","body","author","kind","created","updated","pinned","author_id","body_format"))
    private val prefsNames=listOf("diraasa_preferences_v1","diraasa_devotion_v1")
    private fun journal(db:SQLiteDatabase){db.execSQL("CREATE TABLE IF NOT EXISTS backup_restore_journal(id INTEGER PRIMARY KEY CHECK(id=1),payload TEXT NOT NULL)")}
    private fun preferences(c:Context):JSONObject {
        val result=JSONObject()
        for(name in prefsNames){val values=JSONObject()
            for((key,value) in c.getSharedPreferences(name,Context.MODE_PRIVATE).all){
                if(name=="diraasa_devotion_v1" && key in setOf("pendingLaunch"))continue
                val type=when(value){is String->"string";is Float->"float";is Int->"int";is Long->"long";is Boolean->"boolean";else->continue}
                values.put(key,JSONObject().put("type",type).put("value",value))
            };result.put(name,values)
        };return result
    }
    private fun applyPreferences(c:Context,payload:JSONObject) {
        for(name in prefsNames){val values=payload.getJSONObject(name);val edit=c.getSharedPreferences(name,Context.MODE_PRIVATE).edit().clear()
            for(key in values.keys()){val row=values.getJSONObject(key);when(row.getString("type")){
                "string"->edit.putString(key,row.getString("value"));"float"->edit.putFloat(key,row.getDouble("value").toFloat());"int"->edit.putInt(key,row.getInt("value"));"long"->edit.putLong(key,row.getLong("value"));"boolean"->edit.putBoolean(key,row.getBoolean("value"));else->error("Préférence invalide")
            }};check(edit.commit()){"Restauration des préférences interrompue"}
        }
    }
    fun recover(c:Context) = synchronized(PrayerSyncWorker.lock) { synchronized(lock) {
        var recovered=false
        NotesDatabase(c).use { helper -> val db=helper.writableDatabase;journal(db)
            val payload=db.rawQuery("SELECT payload FROM backup_restore_journal WHERE id=1",null).use { cursor ->
                if(cursor.moveToFirst())cursor.getString(0) else null
            }
            if(payload!=null){applyPreferences(c,JSONObject(payload));db.delete("backup_restore_journal","id=1",null);recovered=true}
        }
        recoveryPending=false
        if(recovered)rebuildSchedules(c)
    }}
    private fun rebuildSchedules(c:Context) {
        try { AzanAlarms.disable(c) } catch (_:Exception) {}
        try {
            ZikrReminders.configure(c,emptyList<Any>())
            val dev=c.getSharedPreferences("diraasa_devotion_v1",Context.MODE_PRIVATE)
            val library=JSONObject(dev.getString("counterLibrary","{}")?:"{}")
            val reminders=library.optJSONArray("reminders")?:JSONArray()
            ZikrReminders.configure(c,(0 until reminders.length()).map{reminders.getJSONObject(it).let{row->row.keys().asSequence().associateWith{key->row.get(key)}}})
        } catch (_:Exception) { /* Device-specific permissions must be re-granted if absent. */ }
        try { PrayerSyncWorker.restoreLatest(c);PrayerSyncWorker.ensure(c) } catch (_:Exception) {}
    }
    fun snapshot(c:Context,target:File) = synchronized(lock) {
        val data=JSONObject().put("applicationId",c.packageName).put("version",1).put("createdAt",System.currentTimeMillis())
        val tableData=JSONObject()
        NotesDatabase(c).use { helper ->val db=helper.writableDatabase
            db.beginTransaction()
            try {for(table in tables.keys){val rows=JSONArray();db.rawQuery("SELECT * FROM $table",null).use { cursor ->
                while(cursor.moveToNext()){val row=JSONObject();for(i in 0 until cursor.columnCount){val value:Any=if(cursor.isNull(i))JSONObject.NULL else when(cursor.getType(i)){1->cursor.getLong(i);2->cursor.getDouble(i);else->cursor.getString(i)};row.put(cursor.getColumnName(i),value)};rows.put(row)}
            };tableData.put(table,rows)};db.setTransactionSuccessful()}finally{db.endTransaction()}
        }
        data.put("tables",tableData).put("preferences",preferences(c))
        val media=linkedMapOf<String,File>();val paths=JSONObject();val bundledAliases=linkedMapOf<String,String>()
        fun visit(value:Any?) {when(value){is JSONObject->for(key in value.keys())visit(value.opt(key));is JSONArray->for(i in 0 until value.length())visit(value.opt(i));is String->{
            if(value.startsWith(c.filesDir.path+"/")){
                val file=File(value).canonicalFile
                val root=c.filesDir.canonicalPath+"/"
                require(file.path.startsWith(root)){"Pièce jointe invalide"}
                if(file.path.startsWith(File(c.filesDir,"bundled_audio").path+"/")){
                    val name=if(file.name=="adhan_2.m4a")"Serigne Mbacké Fall - 🇸🇳 Senegal المسجد طوبي، السنغال.m4a" else file.name
                    require(c.assets.list("audio")?.contains(name)==true){"Son intégré introuvable"}
                    bundledAliases[value]="asset:audio/$name"
                }
                if(file.path.startsWith(File(c.filesDir,"author_photos").path+"/")||file.path.startsWith(File(c.filesDir,"azan_audio").path+"/")||file.path.startsWith(File(c.filesDir,"restored_media").path+"/")){
                    require(file.isFile){"Photo ou son personnel introuvable : ${file.name}"}
                    val ext=file.extension.takeIf{Regex("[a-zA-Z0-9]{1,8}").matches(it)}?:"bin"
                    val name="media/${BackupArchive.hash(file)}.$ext";media[name]=file;paths.put(value,name)
                }
            }
        }}}
        visit(data)
        // Some devotion values are JSON strings. Traverse these too to include custom audio.
        val dev=data.getJSONObject("preferences").getJSONObject("diraasa_devotion_v1")
        for(key in dev.keys()){val v=dev.getJSONObject(key).optString("value");try{visit(JSONTokener(v).nextValue())}catch(_:Exception){}}
        data.put("attachments",paths)
        BackupArchive.write(target,remapData(data,bundledAliases),media)
    }
    fun summary(data:JSONObject):Map<String,Any> {val t=data.getJSONObject("tables");val dev=data.getJSONObject("preferences").getJSONObject("diraasa_devotion_v1")
        val library=try{JSONObject(dev.optJSONObject("counterLibrary")?.optString("value")?:"{}")}catch(_:Exception){JSONObject()}
        return mapOf("createdAt" to data.getLong("createdAt"),"notes" to t.getJSONArray("notes").length(),"authors" to t.getJSONArray("authors").length(),"themes" to (0 until t.getJSONArray("note_references").length()).count{t.getJSONArray("note_references").getJSONObject(it).optString("field")=="title"},"azkar" to (library.optJSONArray("items")?.length()?:0),"wird" to (library.optJSONArray("chains")?.length()?:0),"attachments" to data.getJSONObject("attachments").length())
    }
    fun validate(data:JSONObject,directory:File) {
        val t=data.getJSONObject("tables");require(t.keys().asSequence().toSet()==tables.keys)
        val authors=mutableSetOf<Long>()
        for((table,columns) in tables){val rows=t.getJSONArray(table);require(rows.length()<=200000)
            for(i in 0 until rows.length()){val row=rows.getJSONObject(i);require(row.keys().asSequence().toSet()==columns){"Colonnes incompatibles : $table"}
                if(table=="authors"){require(authors.add(row.getLong("id")));require(NotesDatabase.identity(row.getString("name"))==row.getString("identity"))}
                if(table=="notes" && !row.isNull("author_id"))require(row.getLong("author_id") in authors){"Auteur absent"}
                if(table=="note_references")require(row.getString("field") in setOf("title","author") && NotesDatabase.identity(row.getString("label"))==row.getString("identity"))
            }
        }
        val prefs=data.getJSONObject("preferences");require(prefs.keys().asSequence().toSet()==prefsNames.toSet())
        for(name in prefsNames){val values=prefs.getJSONObject(name);for(key in values.keys()){val row=values.getJSONObject(key);when(row.getString("type")){
            "string"->row.getString("value");"float"->require(row.getDouble("value").isFinite());"int"->row.getInt("value");"long"->row.getLong("value");"boolean"->row.getBoolean("value");else->error("Préférence invalide")
        }}}
        val attachments=data.getJSONObject("attachments")
        for(path in attachments.keys()){val name=attachments.getString(path);require(Regex("media/[0-9a-f]{64}\\.[a-zA-Z0-9]{1,8}").matches(name)&&File(directory,name).isFile)}
    }
    private fun remap(value:Any?,paths:Map<String,String>):Any?=when(value){
        is JSONObject->JSONObject().also{out->for(k in value.keys()){val child=value.opt(k);out.put(k,if(child is String && k !in setOf("audio","fajrAudio","photo"))child else remap(child,paths))}}
        is JSONArray->JSONArray().also{out->for(i in 0 until value.length()){val child=value.opt(i);out.put(if(child is String)child else remap(child,paths))}}
        is String->paths[value]?:value
        else->value
    }
    fun remapData(data:JSONObject,paths:Map<String,String>):JSONObject {
        val restored=JSONObject(data.toString())
        val authors=restored.getJSONObject("tables").getJSONArray("authors")
        for(i in 0 until authors.length()){val author=authors.getJSONObject(i);val photo=author.optString("photo");paths[photo]?.let{author.put("photo",it)}}
        val devotion=restored.getJSONObject("preferences").getJSONObject("diraasa_devotion_v1")
        for(key in devotion.keys()){val row=devotion.getJSONObject(key)
            if(row.optString("type")=="string"){
                val value=row.getString("value")
                try{
                    val mapped=remap(JSONTokener(value).nextValue(),paths)
                    row.put("value",if(mapped is String)JSONObject.quote(mapped) else mapped?.toString()?:"null")
                }catch(_:Exception){}
            }
        }
        return restored
    }
    fun restore(c:Context,data:JSONObject,directory:File):String = synchronized(lock) {
        validate(data,directory)
        val safety=File(c.filesDir,"recovery_backups").apply{mkdirs()}
        val safetyFile=File(safety,"Diraasa_avant_restauration_${System.currentTimeMillis()}.diraasa.zip")
        snapshot(c,safetyFile) // Must finish successfully before any modification.
        val session=File(c.filesDir,"restored_media/${UUID.randomUUID()}").apply{mkdirs()}
        val paths=linkedMapOf<String,String>();val attachments=data.getJSONObject("attachments")
        var committed=false
        try {
            for(old in attachments.keys()){val source=File(directory,attachments.getString(old));val dest=File(session,source.name);source.copyTo(dest,overwrite=true);paths[old]=dest.path}
            val restored=remapData(data,paths)
            NotesDatabase(c).use { helper -> val db=helper.writableDatabase;journal(db);db.beginTransaction()
                try {
                    db.delete("notes",null,null);db.delete("note_references",null,null);db.delete("authors",null,null)
                    for(table in tables.keys){val rows=restored.getJSONObject("tables").getJSONArray(table)
                        for(i in 0 until rows.length()){val row=rows.getJSONObject(i);val values=ContentValues()
                            for(key in row.keys()){val v=row.opt(key);when{v==null||v==JSONObject.NULL->values.putNull(key);v is Number->values.put(key,v.toLong());else->values.put(key,v.toString())}}
                            db.insertOrThrow(table,null,values)
                        }
                    }
                    val journalValues=ContentValues().apply{put("id",1);put("payload",restored.getJSONObject("preferences").toString())}
                    check(db.insertWithOnConflict("backup_restore_journal",null,journalValues,SQLiteDatabase.CONFLICT_REPLACE)!=-1L){"Journal de restauration indisponible"}
                    db.setTransactionSuccessful()
                }finally{db.endTransaction()}
                committed=true
                recoveryPending=true
                applyPreferences(c,restored.getJSONObject("preferences"))
                db.delete("backup_restore_journal","id=1",null)
                recoveryPending=false
            }
            rebuildSchedules(c)
            safetyFile.name
        }catch(e:Exception){if(!committed)session.deleteRecursively()
            if(committed)throw IllegalStateException("Données importées ; finalisation interrompue. Relancez Diraasa pour terminer la restauration.",e)
            throw e}
    }
}
