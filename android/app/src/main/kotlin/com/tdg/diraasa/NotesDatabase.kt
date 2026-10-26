package com.tdg.diraasa

import android.content.Context
import android.content.ContentValues
import java.util.Locale
import java.text.Normalizer
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * notes.db is permanent user data. Never replace it from assets.
 * v0: historical database without user_version.
 * v1: baseline schema. v2: non-destructive ordering index.
 * v3: persistent reusable titles/authors; historical notes remain verbatim.
 * v4: author profiles, stable author_id and plain-text formatting sidecar.
 */
class NotesDatabase(context: Context) : SQLiteOpenHelper(context, "notes.db", null, 4) {
    override fun onCreate(db: SQLiteDatabase) {
        // Also adopts the historical v0 table without touching its rows.
        db.execSQL("CREATE TABLE IF NOT EXISTS notes(id INTEGER PRIMARY KEY,title TEXT,body TEXT,author TEXT,kind TEXT,created INTEGER,updated INTEGER,pinned INTEGER DEFAULT 0)")
        addV2Indexes(db)
        addV3References(db)
        addV4Profiles(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // SQLiteOpenHelper wraps upgrades and version changes in a transaction.
        if (oldVersion < 2) addV2Indexes(db)
        if (oldVersion < 3) addV3References(db)
        if (oldVersion < 4) addV4Profiles(db)
    }

    private fun addV2Indexes(db: SQLiteDatabase) {
        db.execSQL("CREATE INDEX IF NOT EXISTS notes_order ON notes(pinned DESC,updated DESC)")
    }

    private fun addV3References(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS note_references(field TEXT NOT NULL,identity TEXT NOT NULL,label TEXT NOT NULL,PRIMARY KEY(field,identity))")
        // Preserve every historical note verbatim; seed the reusable catalog only.
        db.rawQuery("SELECT title,author FROM notes ORDER BY id", null).use { cursor ->
            while (cursor.moveToNext()) {
                remember(db, "title", cursor.getString(0) ?: "")
                remember(db, "author", cursor.getString(1) ?: "")
            }
        }
    }

    private fun addV4Profiles(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS authors(id INTEGER PRIMARY KEY,identity TEXT NOT NULL UNIQUE,name TEXT NOT NULL,birth TEXT NOT NULL DEFAULT '',death TEXT NOT NULL DEFAULT '',alive INTEGER NOT NULL DEFAULT 1,bio TEXT NOT NULL DEFAULT '',bio_format TEXT NOT NULL DEFAULT '',photo TEXT NOT NULL DEFAULT '')")
        db.execSQL("ALTER TABLE notes ADD COLUMN author_id INTEGER")
        db.execSQL("ALTER TABLE notes ADD COLUMN body_format TEXT NOT NULL DEFAULT ''")
        db.execSQL("CREATE INDEX IF NOT EXISTS notes_author ON notes(author_id)")
        db.rawQuery("SELECT label FROM note_references WHERE field='author'", null).use { c ->
            while (c.moveToNext()) ensureAuthor(db, c.getString(0))
        }
        db.rawQuery("SELECT id,author FROM notes", null).use { c ->
            while (c.moveToNext()) {
                val authorId = ensureAuthor(db, c.getString(1) ?: "")
                if (authorId != null) db.execSQL("UPDATE notes SET author_id=? WHERE id=?", arrayOf(authorId,c.getLong(0)))
            }
        }
    }

    companion object {
        fun identity(input: String) = Normalizer.normalize(input, Normalizer.Form.NFC)
            .replace(Regex("""[\s\p{Z}]+"""), " ").trim().lowercase(Locale.ROOT)
        fun ensureAuthor(db: SQLiteDatabase, input: String): Long? {
            val name = remember(db, "author", input)
            if (name.isEmpty()) return null
            val values = ContentValues().apply { put("identity", identity(name)); put("name", name) }
            db.insertWithOnConflict("authors", null, values, SQLiteDatabase.CONFLICT_IGNORE)
            db.rawQuery("SELECT id FROM authors WHERE identity=?", arrayOf(identity(name))).use {
                check(it.moveToFirst()); return it.getLong(0)
            }
        }

        fun remember(db: SQLiteDatabase, field: String, input: String): String {
            require(field == "title" || field == "author")
            val label = Normalizer.normalize(input, Normalizer.Form.NFC)
                .replace(Regex("""[\s\p{Z}]+"""), " ").trim()
            if (label.isEmpty()) return ""
            val identity = label.lowercase(Locale.ROOT)
            val values = ContentValues().apply {
                put("field", field); put("identity", identity); put("label", label)
            }
            db.insertWithOnConflict("note_references", null, values, SQLiteDatabase.CONFLICT_IGNORE)
            db.rawQuery("SELECT label FROM note_references WHERE field=? AND identity=?", arrayOf(field, identity)).use {
                check(it.moveToFirst())
                return it.getString(0)
            }
        }
    }

    override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Refuse instead of deleting or recreating user data.
        throw IllegalStateException("Version de base plus récente : mise à jour de l'application nécessaire.")
    }
}
