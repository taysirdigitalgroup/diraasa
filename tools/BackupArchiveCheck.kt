import com.tdg.diraasa.BackupArchive
import org.json.JSONObject
import java.io.File
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

fun main(){
    val dir=Files.createTempDirectory("diraasa-backup-check").toFile()
    try{
        val photo=File(dir,"photo.img").apply{writeBytes(byteArrayOf(0,1,2,3,127,-1))}
        val name="media/${BackupArchive.hash(photo)}.img"
        val data=JSONObject().put("version",1).put("applicationId","com.tdg.diraasa")
            .put("text","اللَّه — محمد — é è — Notes")
        val archive=File(dir,"backup.zip")
        BackupArchive.write(archive,data,mapOf(name to photo))
        val output=File(dir,"output")
        val restored=BackupArchive.read(archive,output)
        check(restored.getString("text")==data.getString("text"))
        check(File(output,name).readBytes().contentEquals(photo.readBytes()))
        fun rejects(file:File,label:String){var failed=false
            try{BackupArchive.read(file,File(dir,"reject-${System.nanoTime()}"))}catch(_:Exception){failed=true}
            check(failed){"Archive accepted: $label"}
        }
        val traversal=File(dir,"traversal.zip")
        ZipOutputStream(traversal.outputStream()).use{z->z.putNextEntry(ZipEntry("../outside"));z.write(1);z.closeEntry()}
        rejects(traversal,"path traversal");check(!File(dir,"outside").exists())
        val broken=File(dir,"broken.zip")
        ZipOutputStream(broken.outputStream()).use{z->
            for((entry,text) in mapOf("manifest.json" to """{"format":"com.tdg.diraasa.backup","version":1,"databaseVersion":4,"files":[{"name":"data.json","bytes":2,"sha256":"invalid"}]}""","data.json" to "{}")){
                z.putNextEntry(ZipEntry(entry));z.write(text.toByteArray());z.closeEntry()
            }
        };rejects(broken,"hash mismatch")
        val wrong=File(dir,"wrong.zip")
        BackupArchive.write(wrong,JSONObject().put("version",2).put("applicationId","com.tdg.diraasa"),emptyMap())
        rejects(wrong,"future schema")
        println("OK: ZIP round-trip, Unicode, binary attachments, traversal/hash/version rejection")
    }finally{dir.deleteRecursively()}
}
