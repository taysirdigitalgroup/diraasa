package com.tdg.diraasa

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/** Portable, bounded archive. Hashes detect damage, not authenticity or encryption. */
object BackupArchive {
    const val MAX_BYTES=512L*1024*1024
    const val MAX_JSON=64L*1024*1024
    fun hash(file:File):String = file.inputStream().use { input ->
        val digest=MessageDigest.getInstance("SHA-256");val buffer=ByteArray(65536)
        while(true){val n=input.read(buffer);if(n<0)break;digest.update(buffer,0,n)}
        digest.digest().joinToString(""){"%02x".format(it)}
    }
    fun copyLimited(input:InputStream,file:File,limit:Long):Long {
        var count=0L
        file.outputStream().use { output -> val buffer=ByteArray(65536)
            while(true){val n=input.read(buffer);if(n<0)break;count+=n;require(count<=limit){"Sauvegarde trop volumineuse"};output.write(buffer,0,n)}
        };return count
    }
    fun write(target:File,data:JSONObject,media:Map<String,File>) {
        require(!target.exists()){"La sauvegarde existe déjà"}
        val temporary=File(target.path+".tmp")
        try {
            val dataFile=File.createTempFile("backup-data-",".json",target.parentFile)
            try {
                dataFile.writeText(data.toString(),Charsets.UTF_8)
                require(dataFile.length()<=MAX_JSON)
                val files=linkedMapOf("data.json" to dataFile).apply{putAll(media)}
                require(files.size<=2000 && files.values.sumOf{it.length()}<=MAX_BYTES)
                val manifest=JSONObject().put("format","com.tdg.diraasa.backup").put("version",1)
                    .put("createdAt",System.currentTimeMillis()).put("databaseVersion",4)
                val entries=JSONArray();files.forEach{(name,file)->entries.put(JSONObject().put("name",name).put("bytes",file.length()).put("sha256",hash(file)))}
                manifest.put("files",entries)
                ZipOutputStream(temporary.outputStream().buffered()).use { zip ->
                    zip.putNextEntry(ZipEntry("manifest.json"));zip.write(manifest.toString().toByteArray(Charsets.UTF_8));zip.closeEntry()
                    files.forEach{(name,file)->zip.putNextEntry(ZipEntry(name));file.inputStream().use{it.copyTo(zip)};zip.closeEntry()}
                }
                require(temporary.length()<=MAX_BYTES){"Sauvegarde trop volumineuse"}
                check(temporary.renameTo(target)){"Écriture de la sauvegarde impossible"}
            } finally {dataFile.delete()}
        } finally {temporary.delete()}
    }
    fun read(source:File,directory:File):JSONObject {
        require(source.length() in 1..MAX_BYTES){"Taille de sauvegarde invalide"}
        require(directory.mkdirs()){"Dossier de validation indisponible"}
        var total=0L;val seen=mutableSetOf<String>()
        try {
            ZipInputStream(source.inputStream().buffered()).use { zip ->
                while(true){val entry=zip.nextEntry?:break;val name=entry.name
                    require(!entry.isDirectory && (name=="manifest.json"||name=="data.json"||Regex("media/[0-9a-f]{64}\\.[a-zA-Z0-9]{1,8}").matches(name))){"Chemin d’archive invalide"}
                    require(seen.add(name)&&seen.size<=2001){"Entrée dupliquée ou trop nombreuses"}
                    val file=File(directory,name);file.parentFile?.mkdirs()
                    val limit=if(name=="manifest.json")1024L*1024 else if(name=="data.json")MAX_JSON else MAX_BYTES-total
                    val count=copyLimited(zip,file,minOf(limit,MAX_BYTES-total));total+=count;zip.closeEntry()
                }
            }
            val manifest=JSONObject(File(directory,"manifest.json").readText())
            require(manifest.getString("format")=="com.tdg.diraasa.backup" && manifest.getInt("version")==1 && manifest.getInt("databaseVersion")==4){"Format/version de sauvegarde non pris en charge"}
            val files=manifest.getJSONArray("files");val expected=mutableSetOf("manifest.json")
            for(i in 0 until files.length()){val row=files.getJSONObject(i);val name=row.getString("name")
                require(name in seen && expected.add(name)){"Manifeste invalide"}
                val file=File(directory,name)
                require(file.length()==row.getLong("bytes") && hash(file)==row.getString("sha256")){"Sauvegarde endommagée : $name"}
            }
            require(expected==seen && "data.json" in seen){"Fichiers manquants ou inattendus"}
            val data=JSONObject(File(directory,"data.json").readText(Charsets.UTF_8))
            require(data.getInt("version")==1 && data.getString("applicationId")=="com.tdg.diraasa")
            return data
        }catch(e:Exception){directory.deleteRecursively();throw e}
    }
}
