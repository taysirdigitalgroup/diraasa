package com.tdg.diraasa

import java.io.File
import java.net.URI

/** Android /data/user/0 and /data/data may name the same directory. */
object BackupMedia {
    data class Source(val kind:String,val file:File)
    fun resolve(filesDir:File,value:String):Source? {
        val input=try{if(value.startsWith("file:"))File(URI(value)) else File(value)}catch(_:Exception){return null}
        if(!input.isAbsolute)return null
        val root=filesDir.canonicalFile
        val file=try{input.canonicalFile}catch(_:Exception){return null}
        val relative=file.path.removePrefix(root.path+"/")
        if(relative==file.path)return null
        val kind=relative.substringBefore('/')
        return if(kind in setOf("author_photos","azan_audio","restored_media","bundled_audio"))Source(kind,file) else null
    }
}
