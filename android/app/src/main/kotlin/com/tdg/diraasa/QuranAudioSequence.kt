package com.tdg.diraasa

/** One verse in every selected language before advancing to the next verse. */
class QuranAudioSequence(val languages:List<String>) {
    init { require(languages.size in 1..3 && languages.distinct().size==languages.size && languages.all{it in setOf("ar","fr","en")}) }
    var languageIndex=0; private set
    val language:String get()=languages[languageIndex]
    /** True when every language of the current verse has finished. */
    fun advance():Boolean {
        languageIndex++
        if(languageIndex<languages.size)return false
        languageIndex=0
        return true
    }
    companion object { fun parse(mode:String)=QuranAudioSequence(mode.split("-")) }
}
