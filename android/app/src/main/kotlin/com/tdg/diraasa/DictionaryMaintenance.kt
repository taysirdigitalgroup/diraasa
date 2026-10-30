package com.tdg.diraasa

import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File

/** Read-only book cache only. Never opens notes.db or user data. */
object DictionaryMaintenance {
    const val VERSION=2
    fun prepare(file:File){
        SQLiteDatabase.openDatabase(file.path,null,SQLiteDatabase.OPEN_READWRITE).use{db->
            if(db.version>=VERSION)return
            var removed=0
            db.beginTransaction()
            try{
                db.rawQuery("SELECT COUNT(*) FROM pages WHERE id BETWEEN 1 AND 5",null).use{c->
                    check(c.moveToFirst()&&c.getInt(0)==5){"Introduction du dictionnaire incomplète"}
                }
                removed=db.delete("pages","id>5",null)
                db.version=VERSION
                db.setTransactionSuccessful()
            }finally{db.endTransaction()}
            if(removed>0)try{db.execSQL("VACUUM")}catch(e:Exception){
                // Cleanup is committed; failing to reclaim free disk pages must not block reading.
                Log.w("DiraasaDictionary","Compaction différée : données déjà nettoyées",e)
            }
        }
    }
}
