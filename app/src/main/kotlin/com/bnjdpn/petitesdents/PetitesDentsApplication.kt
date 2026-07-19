package com.bnjdpn.petitesdents

import android.app.Application
import androidx.room.Room
import com.bnjdpn.petitesdents.data.PetitesDentsDatabase
import com.bnjdpn.petitesdents.data.TeethRepository

class PetitesDentsApplication : Application() {
    private val database: PetitesDentsDatabase by lazy {
        Room.databaseBuilder(
            applicationContext,
            PetitesDentsDatabase::class.java,
            "petites-dents.sqlite",
        )
            .addMigrations(PetitesDentsDatabase.MIGRATION_1_2)
            .build()
    }

    val repository: TeethRepository by lazy {
        TeethRepository(
            toothDao = database.toothRecordDao(),
            profileDao = database.childProfileDao(),
        )
    }
}
