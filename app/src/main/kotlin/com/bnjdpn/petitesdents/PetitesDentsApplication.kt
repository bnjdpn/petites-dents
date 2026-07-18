package com.bnjdpn.petitesdents

import android.app.Application
import androidx.room.Room
import com.bnjdpn.petitesdents.data.PetitesDentsDatabase
import com.bnjdpn.petitesdents.data.TeethRepository

class PetitesDentsApplication : Application() {
    val repository: TeethRepository by lazy {
        val database = Room.databaseBuilder(
            applicationContext,
            PetitesDentsDatabase::class.java,
            "petites-dents.sqlite",
        ).build()
        TeethRepository(database.toothRecordDao())
    }
}
