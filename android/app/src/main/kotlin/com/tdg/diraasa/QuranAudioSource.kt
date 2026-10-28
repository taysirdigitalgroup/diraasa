package com.tdg.diraasa

object QuranAudioSource {
    fun filename(chapter:Int,verse:Int):String {
        require(chapter in 1..114 && verse in 0..286 && (verse!=0 || chapter !in setOf(1,9)))
        return "%03d%03d.mp3".format(java.util.Locale.ROOT,chapter,verse)
    }
    fun url(chapter:Int,verse:Int,language:String):String {
        require(language in setOf("ar","fr"))
        return "https://raw.githubusercontent.com/taysirdigitalgroup/diraasa-quran-sounds/main/hafs/$language/${filename(chapter,verse)}"
    }
}
