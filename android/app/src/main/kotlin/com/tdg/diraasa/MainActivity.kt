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
    private var dataChannel: MethodChannel? = null
    private val devotion by lazy { DevotionNative(this) }
    private var quranAudio: QuranAudio? = null
    private var photoResult: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val backup by lazy { BackupNative(this, worker) }
    private var recoveryError: String? = null
    private val main = Handler(Looper.getMainLooper())
    private lateinit var dict: SQLiteDatabase
    private lateinit var notes: SQLiteDatabase
    private lateinit var notesHelper: NotesDatabase
    private fun normalize(s: String) = s.replace(Regex("[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06edـ]"), "")
        .replace(Regex("[أإآٱ]"), "ا").replace('ى','ي').lowercase(java.util.Locale.ROOT)
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        try{BackupStore.recover(this)}catch(e:Exception){recoveryError=e.message?:"Restauration interrompue"}
        try{PrayerSyncWorker.ensure(this)}catch(_:Exception){}
        Thread{try{PrayerSyncWorker.restoreLatest(this)}catch(_:Exception){}}.start()
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "tdg.diraasa/data")
        dataChannel = channel
        channel.setMethodCallHandler { call, result ->
            if (call.method.startsWith("quranAudio")) {
                try {
                    val audio=quranAudio?:QuranAudio(this){value->dataChannel?.invokeMethod("quranAudioChanged",value)}.also{quranAudio=it}
                    val args=call.arguments as? Map<*,*>?:emptyMap<Any,Any>()
                    val value=when(call.method){
                        "quranAudioStart"->audio.start(args)
                        "quranAudioStatus"->audio.status()
                        "quranAudioPause"->audio.pause()
                        "quranAudioResume"->audio.resume()
                        "quranAudioSeek"->audio.seek((args["position"] as? Number)?.toInt()?:0)
                        "quranAudioStop"->audio.stopIfSession(args["session"]?.toString()?:"")
                        else->throw IllegalArgumentException("Commande audio inconnue")
                    }
                    result.success(value)
                }catch(e:Exception){result.error("QURAN_AUDIO",e.message,null)}
                return@setMethodCallHandler
            }
            if (BackupStore.recoveryPending) { try{BackupStore.recover(this)}catch(e:Exception){recoveryError=e.message} }
            if (recoveryError != null) { result.error("RECOVERY",recoveryError,null); return@setMethodCallHandler }
            if (backup.accepts(call.method)) { backup.handle(call,result); return@setMethodCallHandler }
            if (devotion.accepts(call.method)) { devotion.handle(call,result); return@setMethodCallHandler }
            if (call.method == "pickPhoto") {
                if (photoResult != null) { result.error("BUSY", "Sélection déjà ouverte", null); return@setMethodCallHandler }
                photoResult = result
                try { startActivityForResult(android.content.Intent(android.content.Intent.ACTION_OPEN_DOCUMENT).apply {
                    type = "image/*"; addCategory(android.content.Intent.CATEGORY_OPENABLE)
                }, 8401) } catch (e: Exception) { photoResult = null; result.error("PHOTO", e.message, null) }
                return@setMethodCallHandler
            }
            if (call.method == "richClipboard") {
                try {
                    val clip = (getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager).primaryClip
                    val item = clip?.takeIf { it.itemCount > 0 }?.getItemAt(0)
                    val html = item?.htmlText
                    @Suppress("DEPRECATION")
                    val rawText = if (html == null) item?.coerceToText(this) ?: ""
                        else if (android.os.Build.VERSION.SDK_INT >= 24) android.text.Html.fromHtml(html, android.text.Html.FROM_HTML_MODE_LEGACY)
                        else android.text.Html.fromHtml(html)
                    val text = android.text.SpannableStringBuilder(rawText)
                    val bullets = text.getSpans(0,text.length,android.text.style.BulletSpan::class.java)
                        .map { text.getSpanStart(it) }.distinct().sortedDescending()
                    for (start in bullets) if (start >= 0) text.insert(start,"• ")
                    val runs = mutableListOf<Map<String,Any>>()
                    for (span in text.getSpans(0,text.length,Any::class.java)) {
                        val attrs = mutableMapOf<String,Any>()
                        if (span is android.text.style.StyleSpan) {
                            if (span.style and android.graphics.Typeface.BOLD != 0) attrs["b"] = true
                            if (span.style and android.graphics.Typeface.ITALIC != 0) attrs["i"] = true
                        }
                        if (span is android.text.style.QuoteSpan) attrs["q"] = true
                        if (span is android.text.style.UnderlineSpan) attrs["u"] = true
                        if (span is android.text.style.RelativeSizeSpan && span.sizeChange > 1.1f) attrs["h"] = true
                        if (span is android.text.style.BulletSpan) attrs["list"] = true
                        if (attrs.isNotEmpty()) runs.add(mapOf("start" to text.getSpanStart(span), "end" to text.getSpanEnd(span), "attrs" to attrs))
                    }
                    result.success(mapOf("text" to text.toString(),"runs" to runs))
                } catch (e: Exception) { result.error("CLIPBOARD",e.message,null) }
                return@setMethodCallHandler
            }
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
                        "notes" -> query(notes,"SELECT n.*,COALESCE(a.name,n.author) AS author,a.photo AS author_photo FROM notes n LEFT JOIN authors a ON n.author_id=a.id ORDER BY n.pinned DESC,n.updated DESC")
                        "authors" -> query(notes,"SELECT * FROM authors ORDER BY identity")
                        "saveTheme" -> {
                            val label = a["label"]?.toString() ?: ""
                            require(NotesDatabase.identity(label).isNotEmpty()) { "Thème obligatoire" }
                            NotesDatabase.remember(notes,"title",label)
                        }
                        "renameTheme" -> {
                            notes.beginTransaction()
                            try {
                                val oldIdentity = NotesDatabase.identity(a["oldLabel"]?.toString() ?: "")
                                val label = java.text.Normalizer.normalize(a["label"]?.toString() ?: "",java.text.Normalizer.Form.NFC)
                                    .replace(Regex("""[\s\p{Z}]+""")," ").trim()
                                val identity = NotesDatabase.identity(label)
                                require(identity.isNotEmpty()) { "Thème obligatoire" }
                                notes.rawQuery("SELECT label FROM note_references WHERE field='title' AND identity=?",arrayOf(oldIdentity)).use {
                                    check(it.moveToFirst()) { "Thème introuvable" }
                                }
                                notes.rawQuery("SELECT label FROM note_references WHERE field='title' AND identity=?",arrayOf(identity)).use {
                                    check(identity == oldIdentity || !it.moveToFirst()) { "Ce thème existe déjà" }
                                }
                                val ids = mutableListOf<Long>()
                                notes.rawQuery("SELECT id,title FROM notes",null).use { c ->
                                    while (c.moveToNext()) if (NotesDatabase.identity(c.getString(1) ?: "") == oldIdentity) ids.add(c.getLong(0))
                                }
                                for (id in ids) notes.execSQL("UPDATE notes SET title=? WHERE id=?",arrayOf<Any>(label,id))
                                notes.delete("note_references","field='title' AND identity=?",arrayOf(oldIdentity))
                                val canonical = NotesDatabase.remember(notes,"title",label)
                                notes.setTransactionSuccessful(); canonical
                            } finally { notes.endTransaction() }
                        }
                        "deleteTheme" -> {
                            notes.beginTransaction()
                            try {
                                val identity = NotesDatabase.identity(a["label"]?.toString() ?: "")
                                notes.rawQuery("SELECT title FROM notes",null).use { c ->
                                    while (c.moveToNext()) check(NotesDatabase.identity(c.getString(0) ?: "") != identity) { "Ce thème contient des notes" }
                                }
                                val deleted = notes.delete("note_references","field='title' AND identity=?",arrayOf(identity))
                                notes.setTransactionSuccessful(); deleted
                            } finally { notes.endTransaction() }
                        }
                        "deleteAuthor" -> {
                            notes.beginTransaction()
                            try {
                                val id = (a["id"] as Number).toLong()
                                var identity = ""
                                notes.rawQuery("SELECT identity FROM authors WHERE id=?",arrayOf(id.toString())).use {
                                    check(it.moveToFirst()) { "Auteur introuvable" }; identity = it.getString(0)
                                }
                                notes.execSQL("UPDATE notes SET author='',author_id=NULL WHERE author_id=?",arrayOf(id))
                                notes.delete("note_references","field='author' AND identity=?",arrayOf(identity))
                                val deleted = notes.delete("authors","id=?",arrayOf(id.toString()))
                                notes.setTransactionSuccessful(); deleted
                            } finally { notes.endTransaction() }
                        }
                        "saveAuthor" -> {
                            notes.beginTransaction()
                            try {
                                val name = a["name"]?.toString()?.trim() ?: ""
                                require(name.isNotEmpty()) { "Nom obligatoire" }
                                val id = (a["id"] as? Number)?.toLong()
                                val identity = NotesDatabase.identity(name)
                                notes.rawQuery("SELECT id FROM authors WHERE identity=?", arrayOf(identity)).use {
                                    check(!it.moveToFirst() || it.getLong(0) == id) { "Auteur déjà existant" }
                                }
                                val canonical = NotesDatabase.remember(notes,"author",name)
                                val v = ContentValues().apply {
                                    put("name",canonical);put("identity",identity)
                                    for (k in listOf("birth","death","bio","bio_format","photo")) put(k,a[k]?.toString() ?: "")
                                    put("alive",(a["alive"] as? Number)?.toInt() ?: 1)
                                }
                                val savedId = if (id == null) notes.insertOrThrow("authors",null,v) else {
                                    check(notes.update("authors",v,"id=?",arrayOf(id.toString())) == 1); id
                                }
                                notes.execSQL("UPDATE notes SET author=? WHERE author_id=?",arrayOf<Any>(canonical,savedId))
                                if (id != null) notes.execSQL("DELETE FROM note_references WHERE field='author' AND identity NOT IN (SELECT identity FROM authors)")
                                notes.setTransactionSuccessful(); savedId
                            } finally { notes.endTransaction() }
                        }
                        "references" -> {
                            val field = a["field"]?.toString() ?: ""
                            require(field == "title" || field == "author")
                            if (field == "author") query(notes,"SELECT name AS label FROM authors ORDER BY identity")
                            else query(notes, "SELECT label FROM note_references WHERE field=? ORDER BY identity", arrayOf(field))
                        }
                        "save" -> {
                            notes.beginTransaction()
                            try {
                                val v=ContentValues()
                                for(k in listOf("body","kind","body_format")) v.put(k,a[k]?.toString() ?: "")
                                for(k in listOf("title","author")) v.put(k, NotesDatabase.remember(notes,k,a[k]?.toString() ?: ""))
                                val authorId = NotesDatabase.ensureAuthor(notes, a["author"]?.toString() ?: "")
                                if (authorId == null) v.putNull("author_id") else v.put("author_id",authorId)
                                v.put("updated",System.currentTimeMillis())
                                val id=(a["id"] as? Number)?.toLong()
                                val savedId = if(id==null) {
                                    v.put("created",System.currentTimeMillis());notes.insertOrThrow("notes",null,v)
                                } else {
                                    check(notes.update("notes",v,"id=?",arrayOf(id.toString())) == 1) { "Note introuvable." }; id
                                }
                                notes.setTransactionSuccessful()
                                savedId
                            } finally { notes.endTransaction() }
                        }
                        "delete" -> notes.delete("notes","id=?",arrayOf(a["id"].toString()))
                        "pin" -> {notes.execSQL("UPDATE notes SET pinned=1-pinned WHERE id=?",arrayOf(a["id"]));true}
                        "intro" -> query(dict,"SELECT * FROM pages WHERE id<=5")
                        "search", "searchCount" -> {
                            val rawQuery = a["q"]?.toString()?.trim() ?: ""
                            val precise = Regex("""[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]""").containsMatchIn(rawQuery) || rawQuery != rawQuery.lowercase(java.util.Locale.ROOT)
                            val fulltext = a["mode"] == "fulltext" || a["mode"] == "Texte intégral"
                            val contains = a["mode"] == "contains" || a["mode"] == "Contient"
                            val q=normalize(rawQuery)
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
                            if (precise && !fulltext && rawQuery.isNotEmpty()) {
                                if (contains) {
                                    clauses.add("(instr(e.word,?)>0 OR instr(REPLACE(e.root,' ',''),?)>0)")
                                } else {
                                    clauses.add("(substr(e.word,1,length(?))=? COLLATE BINARY OR substr(REPLACE(e.root,' ',''),1,length(?))=? COLLATE BINARY)")
                                }
                                val rootQuery = rawQuery.replace(" ","")
                                if (contains) { args.add(rawQuery);args.add(rootQuery) }
                                else { args.add(rawQuery);args.add(rawQuery);args.add(rootQuery);args.add(rootQuery) }
                            }
                            val where=if(clauses.isEmpty()) "" else " WHERE "+clauses.joinToString(" AND ")
                            val baseSql = "SELECT e.* FROM entries e$where ORDER BY e.normalized,e.id"
                            if (precise && fulltext) {
                                // Refine FTS candidates before pagination, preserving harakat/case.
                                val pattern = Regex("""[\p{L}\p{N}\p{M}]+""")
                                val terms = pattern.findAll(rawQuery).map { it.value }.toList()
                                val matches=query(dict,baseSql,args.toTypedArray()).filter { row ->
                                    val words = listOf("word","definition","root").flatMap { key ->
                                        pattern.findAll(row[key]?.toString() ?: "").map { it.value }.toList()
                                    }
                                    terms.isNotEmpty() && terms.all { term -> words.any { it.startsWith(term) } }
                                }
                                if(call.method=="searchCount")matches.size else matches.drop(offset).take(60)
                            } else if(call.method=="searchCount")query(dict,"SELECT COUNT(*) AS total FROM entries e$where",args.toTypedArray()).first()["total"]
                            else query(dict,baseSql+" LIMIT 60 OFFSET ?",(args+offset.toString()).toTypedArray())
                        }
                        else -> throw IllegalArgumentException("Méthode inconnue")
                    }
                    main.post {result.success(value)}
                } catch(e:Exception){main.post{result.error("DATA",e.message,null)}}
            }
        }
    }
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if(intent.hasExtra("devotionTarget"))dataChannel?.invokeMethod("devotionPending",null)
    }
    override fun onDestroy() {
        quranAudio?.close()
        super.onDestroy()
    }

    override fun onStop() {
        quranAudio?.stop()
        super.onStop()
    }

    @Deprecated("Android activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if (backup.activityResult(requestCode,resultCode,data)) return
        if (devotion.activityResult(requestCode,resultCode,data)) return
        if (requestCode != 8401) return
        val result = photoResult ?: return
        photoResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { result.success(null); return }
        worker.execute {
            try {
                val folder = java.io.File(filesDir,"author_photos").apply { mkdirs() }
                val target = java.io.File(folder,java.util.UUID.randomUUID().toString()+".img")
                try {
                    contentResolver.openInputStream(uri)!!.use { input -> target.outputStream().use { input.copyTo(it) } }
                    val opts = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    android.graphics.BitmapFactory.decodeFile(target.path,opts)
                    check(opts.outWidth > 0 && opts.outHeight > 0) { "Image invalide" }
                } catch (e: Exception) { target.delete(); throw e }
                main.post { result.success(target.path) }
            } catch (e: Exception) { main.post { result.error("PHOTO",e.message,null) } }
        }
    }

}
