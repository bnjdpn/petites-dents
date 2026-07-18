package com.bnjdpn.petitesdents.data

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.RoomDatabase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

enum class ToothArch { UPPER, LOWER }
enum class ToothSide { LEFT, RIGHT }
enum class ToothKind { CENTRAL_INCISOR, LATERAL_INCISOR, CANINE, FIRST_MOLAR, SECOND_MOLAR }
enum class ToothStatus { GHOST, TEETHING, ERUPTED }

data class ToothDefinition(
    val id: String,
    val fdi: Int,
    val arch: ToothArch,
    val side: ToothSide,
    val kind: ToothKind,
    val minMonths: Int,
    val maxMonths: Int,
)

object ToothCatalog {
    val upper: List<ToothDefinition> = listOf(
        tooth(65, ToothArch.UPPER, ToothSide.LEFT, ToothKind.SECOND_MOLAR, 25, 33),
        tooth(64, ToothArch.UPPER, ToothSide.LEFT, ToothKind.FIRST_MOLAR, 13, 19),
        tooth(63, ToothArch.UPPER, ToothSide.LEFT, ToothKind.CANINE, 16, 22),
        tooth(62, ToothArch.UPPER, ToothSide.LEFT, ToothKind.LATERAL_INCISOR, 9, 13),
        tooth(61, ToothArch.UPPER, ToothSide.LEFT, ToothKind.CENTRAL_INCISOR, 8, 12),
        tooth(51, ToothArch.UPPER, ToothSide.RIGHT, ToothKind.CENTRAL_INCISOR, 8, 12),
        tooth(52, ToothArch.UPPER, ToothSide.RIGHT, ToothKind.LATERAL_INCISOR, 9, 13),
        tooth(53, ToothArch.UPPER, ToothSide.RIGHT, ToothKind.CANINE, 16, 22),
        tooth(54, ToothArch.UPPER, ToothSide.RIGHT, ToothKind.FIRST_MOLAR, 13, 19),
        tooth(55, ToothArch.UPPER, ToothSide.RIGHT, ToothKind.SECOND_MOLAR, 25, 33),
    )

    val lower: List<ToothDefinition> = listOf(
        tooth(75, ToothArch.LOWER, ToothSide.LEFT, ToothKind.SECOND_MOLAR, 25, 33),
        tooth(74, ToothArch.LOWER, ToothSide.LEFT, ToothKind.FIRST_MOLAR, 13, 19),
        tooth(73, ToothArch.LOWER, ToothSide.LEFT, ToothKind.CANINE, 16, 22),
        tooth(72, ToothArch.LOWER, ToothSide.LEFT, ToothKind.LATERAL_INCISOR, 10, 16),
        tooth(71, ToothArch.LOWER, ToothSide.LEFT, ToothKind.CENTRAL_INCISOR, 6, 10),
        tooth(81, ToothArch.LOWER, ToothSide.RIGHT, ToothKind.CENTRAL_INCISOR, 6, 10),
        tooth(82, ToothArch.LOWER, ToothSide.RIGHT, ToothKind.LATERAL_INCISOR, 10, 16),
        tooth(83, ToothArch.LOWER, ToothSide.RIGHT, ToothKind.CANINE, 16, 22),
        tooth(84, ToothArch.LOWER, ToothSide.RIGHT, ToothKind.FIRST_MOLAR, 13, 19),
        tooth(85, ToothArch.LOWER, ToothSide.RIGHT, ToothKind.SECOND_MOLAR, 25, 33),
    )

    val all: List<ToothDefinition> = upper + lower

    private fun tooth(
        fdi: Int,
        arch: ToothArch,
        side: ToothSide,
        kind: ToothKind,
        minMonths: Int,
        maxMonths: Int,
    ) = ToothDefinition(
        id = "tooth-$fdi",
        fdi = fdi,
        arch = arch,
        side = side,
        kind = kind,
        minMonths = minMonths,
        maxMonths = maxMonths,
    )
}

@Entity(tableName = "tooth_records", primaryKeys = ["childId", "toothId"])
data class ToothRecordEntity(
    val childId: String = PRIMARY_CHILD_ID,
    val toothId: String,
    val teethingEpochDay: Long? = null,
    val eruptedEpochDay: Long? = null,
    val note: String = "",
) {
    val status: ToothStatus
        get() = when {
            eruptedEpochDay != null -> ToothStatus.ERUPTED
            teethingEpochDay != null -> ToothStatus.TEETHING
            else -> ToothStatus.GHOST
        }

    fun markTeething(epochDay: Long, updatedNote: String): ToothRecordEntity = copy(
        teethingEpochDay = epochDay,
        eruptedEpochDay = null,
        note = updatedNote.trim(),
    )

    fun markErupted(epochDay: Long, updatedNote: String): ToothRecordEntity {
        require(teethingEpochDay == null || epochDay >= teethingEpochDay) {
            "Eruption date cannot precede teething date"
        }
        return copy(eruptedEpochDay = epochDay, note = updatedNote.trim())
    }

    companion object {
        const val PRIMARY_CHILD_ID = "primary"
    }
}

data class ToothSnapshot(
    val definition: ToothDefinition,
    val record: ToothRecordEntity,
)

@Dao
interface ToothRecordDao {
    @Query("SELECT * FROM tooth_records WHERE childId = :childId")
    fun observe(childId: String = ToothRecordEntity.PRIMARY_CHILD_ID): Flow<List<ToothRecordEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(record: ToothRecordEntity)

    @Query("DELETE FROM tooth_records WHERE childId = :childId AND toothId = :toothId")
    suspend fun delete(childId: String, toothId: String)
}

@Database(entities = [ToothRecordEntity::class], version = 1, exportSchema = false)
abstract class PetitesDentsDatabase : RoomDatabase() {
    abstract fun toothRecordDao(): ToothRecordDao
}

class TeethRepository(private val dao: ToothRecordDao) {
    val teeth: Flow<List<ToothSnapshot>> = dao.observe().map { records ->
        val byId = records.associateBy(ToothRecordEntity::toothId)
        ToothCatalog.all.map { definition ->
            ToothSnapshot(
                definition = definition,
                record = byId[definition.id] ?: ToothRecordEntity(toothId = definition.id),
            )
        }
    }

    suspend fun saveNote(snapshot: ToothSnapshot, note: String) {
        dao.upsert(snapshot.record.copy(note = note.trim()))
    }

    suspend fun markTeething(snapshot: ToothSnapshot, epochDay: Long, note: String) {
        dao.upsert(snapshot.record.markTeething(epochDay, note))
    }

    suspend fun markErupted(snapshot: ToothSnapshot, epochDay: Long, note: String) {
        dao.upsert(snapshot.record.markErupted(epochDay, note))
    }

    suspend fun reset(snapshot: ToothSnapshot) {
        dao.delete(snapshot.record.childId, snapshot.record.toothId)
    }
}
