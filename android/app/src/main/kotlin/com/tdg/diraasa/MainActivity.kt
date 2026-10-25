package com.tdg.diraasa

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private lateinit var dict: SQLiteDatabase
    private lateinit var notes: SQLiteDatabase
    private lateinit var notesHelper: NotesDatabase
    private fun normalize(s: String) = s.replace(Regex("[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06edـ]"), "")
        .replace(Regex("[أإآٱ]"), "ا").replace('ى','ي')
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "tdg.diraasa/data").setMethodCallHandler { call, result ->
            worker.execute {
                try {
                    if (call.method == "preferences" || call.method == "savePreferences") {
                        val prefs = getSharedPreferences("diraasa_preferences_v1", MODE_PRIVATE)
                        val value: Any = if (call.method == "preferences") {
                            prefs.all
                        } else {
                            val values = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                            val edit = prefs.edit()
                            for (key in listOf("language", "theme", "draftTitle", "draftAuthor", "draftKind", "noteCategory", "noteField", "dictionaryMode", "dictionaryLetter")) {
                                (values[key] as? String)?.let { edit.putString(key, it) }
                            }
                            (values["textSize"] as? Number)?.let { edit.putFloat("textSize", it.toFloat()) }
                            check(edit.commit()) { "Impossible de sauvegarder les préférences." }
                            true
                        }
                        main.post { result.success(value) }
                        return@execute
                    }
                    if (!::dict.isInitialized) {
                        val target = getDatabasePath("dictionary_v1.db")
                        target.parentFile?.mkdirs()
                        if (!target.exists()) {
                            val tmp = java.io.File(target.path + ".tmp")
                            assets.open("dictionary.db").use { input -> tmp.outputStream().use { input.copyTo(it) } }
                            check(tmp.renameTo(target))
                        }
                        dict = SQLiteDatabase.openDatabase(target.path,null,SQLiteDatabase.OPEN_READONLY)
                    }
                    if (!::notes.isInitialized) {
                        notesHelper = NotesDatabase(this)
                        notes = notesHelper.writableDatabase
                    }
                    val a = call.arguments as? Map<*,*> ?: emptyMap<Any,Any>()
                    fun query(db:SQLiteDatabase,sql:String,args:Array<String> = emptyArray()):List<Map<String,Any?>> {
                        db.rawQuery(sql,args).use { c ->
                            val rows = mutableListOf<Map<String,Any?>>()
                            while(c.moveToNext()) rows.add(c.columnNames.mapIndexed { i,k -> k to (if(c.isNull(i)) null else if(c.getType(i)==1) c.getLong(i) else c.getString(i)) }.toMap())
                            return rows
                        }
                    }
                    val value:Any? = when(call.method) {
                        "notes" -> query(notes,"SELECT * FROM notes ORDER BY pinned DESC,updated DESC")
                        "save" -> {
                            val v=ContentValues()
                            for(k in listOf("title","body","author","kind")) v.put(k,a[k]?.toString() ?: "")
                            v.put("updated",System.currentTimeMillis())
                            val id=(a["id"] as? Number)?.toLong()
                            if(id==null) {v.put("created",System.currentTimeMillis());notes.insertOrThrow("notes",null,v)}
                            else { check(notes.update("notes",v,"id=?",arrayOf(id.toString())) == 1) { "Note introuvable." }; id }
                        }
                        "delete" -> notes.delete("notes","id=?",arrayOf(a["id"].toString()))
                        "pin" -> {notes.execSQL("UPDATE notes SET pinned=1-pinned WHERE id=?",arrayOf(a["id"]));true}
                        "intro" -> query(dict,"SELECT * FROM pages WHERE id<=5")
                        "search" -> {
                            val q=normalize(a["q"]?.toString() ?: "").trim()
                            val letter=normalize(a["letter"]?.toString() ?: "")
                            val offset=(a["offset"] as? Number)?.toInt() ?: 0
                            val clauses=mutableListOf<String>()
                            val args=mutableListOf<String>()
                            val rootExpr = "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(e.root,' ',''),'ـ',''),'أ','ا'),'إ','ا'),'آ','ا'),'ٱ','ا'),'ى','ي')"
                            if(letter.isNotEmpty()){clauses.add("e.letter=?");args.add(letter)}
                            if(q.isNotEmpty()){
                                if((a["mode"]=="fulltext" || a["mode"]=="Texte intégral")){
                                    val tokens=Regex("""[\p{L}\p{N}]+""").findAll(q).map{it.value+"*"}.toList()
                                    if(tokens.isEmpty()) clauses.add("0")
                                    else {clauses.add("e.id IN (SELECT docid FROM search WHERE terms MATCH ?)");args.add(tokens.joinToString(" AND "))}
                                } else {clauses.add("(e.normalized LIKE ? ESCAPE '\\' OR ${rootExpr} LIKE ? ESCAPE '\\')")
                                    val escaped=q.replace("\\","\\\\").replace("%","\\%").replace("_","\\_")
                                    val pattern=if((a["mode"]=="contains" || a["mode"]=="Contient")) "%$escaped%" else "$escaped%"
                                    args.add(pattern);args.add(pattern)
                                }
                            }
                            val where=if(clauses.isEmpty()) "" else " WHERE "+clauses.joinToString(" AND ")
                            query(dict,"SELECT e.* FROM entries e$where ORDER BY e.normalized,e.id LIMIT 60 OFFSET ?",(args+offset.toString()).toTypedArray())
                        }
                        else -> throw IllegalArgumentException("Méthode inconnue")
                    }
                    main.post {result.success(value)}
                } catch(e:Exception){main.post{result.error("DATA",e.message,null)}}
            }
        }
    }
}
