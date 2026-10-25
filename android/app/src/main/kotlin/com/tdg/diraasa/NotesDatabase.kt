package com.tdg.diraasa

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * notes.db is permanent user data. Never replace it from assets.
 * v0: historical database without user_version.
 * v1: baseline schema. v2: non-destructive ordering index.
 */
class NotesDatabase(context: Context) : SQLiteOpenHelper(context, "notes.db", null, 2) {
    override fun onCreate(db: SQLiteDatabase) {
        // Also adopts the historical v0 table without touching its rows.
        db.execSQL("CREATE TABLE IF NOT EXISTS notes(id INTEGER PRIMARY KEY,title TEXT,body TEXT,author TEXT,kind TEXT,created INTEGER,updated INTEGER,pinned INTEGER DEFAULT 0)")
        addV2Indexes(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // SQLiteOpenHelper wraps upgrades and version changes in a transaction.
        if (oldVersion < 2) addV2Indexes(db)
    }

    private fun addV2Indexes(db: SQLiteDatabase) {
        db.execSQL("CREATE INDEX IF NOT EXISTS notes_order ON notes(pinned DESC,updated DESC)")
    }

    override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Refuse instead of deleting or recreating user data.
        throw IllegalStateException("Version de base plus récente : mise à jour de l'application nécessaire.")
    }
}
