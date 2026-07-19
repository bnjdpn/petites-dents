package com.bnjdpn.petitesdents

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.bnjdpn.petitesdents.data.TeethRepository
import com.bnjdpn.petitesdents.data.ToothSnapshot
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class TeethViewModel(private val repository: TeethRepository) : ViewModel() {
    val teeth = repository.teeth.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = emptyList(),
    )

    val birthDateEpochDay = repository.birthDateEpochDay.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = null,
    )

    fun saveNote(snapshot: ToothSnapshot, note: String) {
        viewModelScope.launch { repository.saveNote(snapshot, note) }
    }

    fun markTeething(snapshot: ToothSnapshot, epochDay: Long, note: String) {
        viewModelScope.launch { repository.markTeething(snapshot, epochDay, note) }
    }

    fun markErupted(snapshot: ToothSnapshot, epochDay: Long, note: String) {
        viewModelScope.launch { repository.markErupted(snapshot, epochDay, note) }
    }

    fun reset(snapshot: ToothSnapshot) {
        viewModelScope.launch { repository.reset(snapshot) }
    }

    fun saveBirthDate(epochDay: Long?) {
        viewModelScope.launch { repository.saveBirthDate(epochDay) }
    }

    class Factory(private val repository: TeethRepository) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            require(modelClass.isAssignableFrom(TeethViewModel::class.java))
            return TeethViewModel(repository) as T
        }
    }
}
