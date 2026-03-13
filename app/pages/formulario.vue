<script setup lang="ts">
import {
  AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription,
  AlertDialogOverlay, AlertDialogPortal, AlertDialogRoot, AlertDialogTitle
} from 'reka-ui'

const userId = useCookie('user_id')
const workerToken = useCookie('worker_token')
const currentStep = ref(1)
const saving = ref(false)
const loadingData = ref(true)
const isLocked = ref(false)

// --- CONFIGURACIÓN DE ALERTAS (REKA UI) ---
const isAlertOpen = ref(false)
const alertConfig = reactive({
  title: '',
  description: '',
  isConfirm: false,
  onAction: () => { isAlertOpen.value = false }
})

const showAlert = (title: string, desc: string, isConfirm = false, actionCallback?: () => void) => {
  alertConfig.title = title
  alertConfig.description = desc
  alertConfig.isConfirm = isConfirm
  alertConfig.onAction = actionCallback || (() => { isAlertOpen.value = false })
  isAlertOpen.value = true
}

// --- ESTADO DEL FORMULARIO ---
const formData = reactive({
  worker: { nombre: '', rut: '', cargo: '', area: '', email: '', telefono: '' },
  dependent: {
    nombre: '', rut: '', nacimiento: '', edad: '', parentesco: '',
    prevision: '', isapreNombre: '', email: '', telefono: '', otroParentesco: ''
  },
  bank: { banco: '', tipo: '', numero: '', otroTipo: '' },
  fechaSolicitud: new Date().toLocaleDateString('es-CL')
})

// --- CARGA DE DATOS ---
onMounted(async () => {
  if (!userId.value) return navigateTo('/')
  try {
    const data: any = await $fetch(`http://localhost:4000/api/submissions/${userId.value}`, {
      headers: {
        Authorization: `Bearer ${workerToken.value}`
      }
    })
    if (data) {
      if (data.status === 'submitted') isLocked.value = true

      formData.worker = {
        nombre: data.workerName || '', rut: data.workerRut || '', cargo: data.workerCargo || '',
        area: data.workerArea || '', email: data.workerEmail || '', telefono: data.workerPhone || ''
      }
      formData.dependent = {
        nombre: data.depName || '', rut: data.depRut || '', nacimiento: data.depBirthDate || '',
        edad: data.depAge || '', parentesco: data.depRelationship || '',
        prevision: data.depHealthSystem || '', isapreNombre: data.depIsapreName || '',
        email: data.depEmail || '', telefono: data.depPhone || '', otroParentesco: data.depOtherRel || ''
      }
      formData.bank = {
        banco: data.bankName || '', tipo: data.bankAccountType || '',
        numero: data.bankAccountNumber || '', otroTipo: data.bankOtherType || ''
      }

      if (isLocked.value) {
        showAlert("Formulario Enviado", "Este documento ya fue enviado a RR.HH. y no permite más cambios.", false, () => navigateTo('/'))
      }
    }
  } catch (e) { console.warn("Nuevo formulario") }
  finally { loadingData.value = false }
})

// --- VALIDACIÓN ESTRICTA DE TODOS LOS CAMPOS ---
const validateStep = () => {
  const s = currentStep.value

  // Paso 1: Datos del Trabajador [cite: 11-17]
  if (s === 1) {
    const w = formData.worker
    if (!w.nombre || !w.rut || !w.cargo || !w.area || !w.email || !w.telefono) {
      return "Todos los campos de la sección del Trabajador son obligatorios."
    }
  }

  // Paso 2: Datos de la Carga [cite: 18-35]
  if (s === 2) {
    const d = formData.dependent
    if (!d.nombre || !d.rut || !d.nacimiento || !d.edad || !d.parentesco || !d.prevision || !d.email || !d.telefono) {
      return "Todos los campos de la sección de la Carga son obligatorios."
    }
    // Validaciones condicionales
    if (d.parentesco === 'Otro' && !d.otroParentesco) {
      return "Debe especificar el parentesco en el campo 'Otro'."
    }
    if (d.prevision === 'Isapre' && !d.isapreNombre) {
      return "Debe indicar el nombre de su Isapre."
    }
  }

  // Paso 3: Datos Bancarios [cite: 40-52]
  if (s === 3) {
    const b = formData.bank
    if (!b.banco || !b.tipo || !b.numero) {
      return "Todos los campos de la sección de Datos Bancarios son obligatorios."
    }
    if (b.tipo === 'Otro' && !b.otroTipo) {
      return "Debe especificar el tipo de cuenta en el campo 'Otro'."
    }
  }

  return null
}

async function handleNavigation(finalize = false) {
  if (isLocked.value) return
  const error = validateStep()
  if (error) return showAlert("Información Incompleta", error)

  if (finalize) {
    showAlert("¿Enviar a RR.HH.?", "Confirmas que los datos son verídicos. No podrás editarlos luego.", true, executeSave)
  } else {
    executeSave()
  }
}

async function executeSave() {
  saving.value = true
  const isFinal = alertConfig.isConfirm
  try {
    await $fetch('http://localhost:4000/api/submissions/save', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${workerToken.value}` // <--- Token de seguridad
      },
      body: {
        userId: Number(userId.value),
        data: formData,
        finalize: isFinal
      }
    })

    if (isFinal) {
      // Al finalizar, limpiamos las cookies 
      showAlert("¡Éxito!", "Formulario enviado correctamente a RR.HH.", false, () => {
        userId.value = null;
        workerToken.value = null;
        navigateTo('/')
      })
    } else {
      currentStep.value++;
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  } catch (e) {
    showAlert("Error", "No tienes permisos o la sesión ha expirado.")
  } finally {
    saving.value = false
  }
}

async function saveAndExit() {
  saving.value = true
  try {
    // Guardamos con finalize: false para que quede como 'draft'
    await $fetch('http://localhost:4000/api/submissions/save', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${workerToken.value}`
      },
      body: {
        userId: Number(userId.value),
        data: formData,
        finalize: false
      }
    })

    showAlert(
      "Progreso Guardado",
      "Tu información se ha guardado como borrador. Puedes volver con tu RUT cuando quieras para terminar.",
      false,
      () => {
        // Limpiamos la sesión para seguridad y volvemos al inicio
        userId.value = null
        workerToken.value = null
        navigateTo('/')
      }
    )
  } catch (e) {
    showAlert("Error", "No se pudo guardar el progreso. Revisa tu conexión.")
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-slate-100 pb-20 font-sans text-slate-900">
    <nav class="bg-blue-900 text-white p-5 shadow-lg mb-8 sticky top-0 z-50">
      <div class="max-w-3xl mx-auto flex justify-between items-center">
        <div>
          <span class="font-black text-2xl tracking-tighter italic uppercase">P&B</span>
          <span class="ml-2 text-xs border-l pl-2 opacity-70 uppercase tracking-widest text-center">Ingeniería</span>
        </div>
        <div class="bg-blue-800 px-3 py-1 rounded text-[10px] font-bold uppercase tracking-widest text-center">
          Procedimientos RR.HH.
        </div>
      </div>
    </nav>

    <div v-if="loadingData" class="flex justify-center p-20 font-bold text-blue-900 animate-pulse">CARGANDO...</div>

    <div v-else class="max-w-3xl mx-auto px-4">
      <div class="flex items-center mb-8 justify-between px-2">
        <div v-for="i in 3" :key="i" class="flex flex-col items-center flex-1">
          <div
            :class="['w-10 h-10 rounded-full flex items-center justify-center font-bold transition-all shadow-sm', currentStep >= i ? 'bg-blue-900 text-white scale-110' : 'bg-white text-slate-300 border-2 border-slate-200']">
            {{ i }}</div>
          <span class="text-[10px] mt-2 font-bold uppercase tracking-tighter"
            :class="currentStep >= i ? 'text-blue-900' : 'text-slate-400'">
            {{ i === 1 ? 'Trabajador' : i === 2 ? 'Carga' : 'Banco' }}
          </span>
        </div>
      </div>

      <div class="bg-white rounded-3xl shadow-xl border border-slate-200 overflow-hidden"
        :class="{ 'opacity-60 pointer-events-none': isLocked }">
        <div class="p-8">

          <div v-if="currentStep === 1" class="space-y-6">
            <h2 class="text-xl font-black text-slate-800 uppercase border-b-2 border-blue-900 pb-2 tracking-tight">1.
              Datos del Trabajador</h2>
            <div class="grid grid-cols-1 gap-4">
              <div><label class="label-style">Nombre Completo *</label><input v-model="formData.worker.nombre"
                  class="input-style" placeholder="Ej: Juan Pérez" /></div>
              <div class="grid grid-cols-2 gap-4">
                <div><label class="label-style">RUT *</label><input v-model="formData.worker.rut" class="input-style"
                    placeholder="12.345.678-9" /></div>
                <div><label class="label-style">Cargo *</label><input v-model="formData.worker.cargo"
                    class="input-style" placeholder="Ej: Operador" /></div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div><label class="label-style">Área / Depto *</label><input v-model="formData.worker.area"
                    class="input-style" placeholder="Ej: Mantenimiento" /></div>
                <div><label class="label-style">Teléfono *</label><input v-model="formData.worker.telefono"
                    class="input-style" placeholder="9 1234 5678" /></div>
              </div>
              <div><label class="label-style">Email *</label><input v-model="formData.worker.email" type="email"
                  class="input-style" placeholder="ejemplo@pyb.cl" /></div>
            </div>
          </div>

          <div v-if="currentStep === 2" class="space-y-6">
            <h2 class="text-xl font-black text-slate-800 uppercase border-b-2 border-blue-900 pb-2 tracking-tight">2.
              Datos de la Carga a Incorporar</h2>
            <div class="space-y-4">
              <div><label class="label-style">Nombre Completo Carga *</label><input v-model="formData.dependent.nombre"
                  class="input-style" placeholder="Ej: Ana Pérez" /></div>
              <div class="grid grid-cols-2 gap-4">
                <div><label class="label-style">RUT Carga *</label><input v-model="formData.dependent.rut"
                    class="input-style" placeholder="22.345.678-9" /></div>
                <div><label class="label-style">Fec. Nacimiento *</label><input v-model="formData.dependent.nacimiento"
                    type="date" class="input-style" placeholder="dd/mm/aaaa" /></div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div><label class="label-style">Edad *</label><input v-model="formData.dependent.edad" type="number"
                    class="input-style" placeholder="0" /></div>
                <div><label class="label-style">Parentesco *</label>
                  <select v-model="formData.dependent.parentesco" class="input-style">
                    <option value="">Seleccione...</option>
                    <option value="Cónyuge">Cónyuge</option>
                    <option value="Conviviente Civil">Conviviente Civil</option>
                    <option value="Hijo/a">Hijo/a</option>
                    <option value="Otro">Otro (especificar)</option>
                  </select>
                </div>
              </div>
              <div v-if="formData.dependent.parentesco === 'Otro'">
                <label class="label-style">Especificar Parentesco *</label>
                <input v-model="formData.dependent.otroParentesco" class="input-style"
                  placeholder="Ej: Madre, Padre..." />
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div><label class="label-style">Email Carga *</label><input v-model="formData.dependent.email"
                    type="email" class="input-style" placeholder="ejemplo@pyb.cl" /></div>
                <div><label class="label-style">Teléfono Carga *</label><input v-model="formData.dependent.telefono"
                    class="input-style" placeholder="9 1234 5678" /></div>
              </div>

              <div>
                <label class="label-style">Sistema / Plan de Salud *</label>
                <div class="flex gap-4">
                  <button @click="formData.dependent.prevision = 'Fonasa'"
                    :class="['flex-1 p-3 border rounded-xl font-bold transition', formData.dependent.prevision === 'Fonasa' ? 'bg-blue-900 text-white border-blue-900' : 'bg-slate-50 text-slate-400']">FONASA</button>
                  <button @click="formData.dependent.prevision = 'Isapre'"
                    :class="['flex-1 p-3 border rounded-xl font-bold transition', formData.dependent.prevision === 'Isapre' ? 'bg-blue-900 text-white border-blue-900' : 'bg-slate-50 text-slate-400']">ISAPRE</button>
                </div>
              </div>
              <div v-if="formData.dependent.prevision === 'Isapre'" class="animate-in fade-in duration-300">
                <label class="label-style">Indicar Nombre Isapre *</label>
                <input v-model="formData.dependent.isapreNombre" class="input-style"
                  placeholder="Ej: Colmena, Banmédica..." />
              </div>
            </div>
          </div>

          <div v-if="currentStep === 3" class="space-y-6">
            <h2 class="text-xl font-black text-slate-800 uppercase border-b-2 border-blue-900 pb-2 tracking-tight">3.
              Datos Bancarios de la Carga</h2>
            <div class="space-y-4">
              <div><label class="label-style">Banco *</label><input v-model="formData.bank.banco" class="input-style"
                  placeholder="Ej: Banco Estado" /></div>
              <div class="grid grid-cols-2 gap-4">
                <div><label class="label-style">Tipo de Cuenta *</label>
                  <select v-model="formData.bank.tipo" class="input-style">
                    <option value="">Seleccione...</option>
                    <option value="Cuenta Corriente">Cuenta Corriente</option>
                    <option value="Cuenta Vista">Cuenta Vista</option>
                    <option value="Cuenta RUT">Cuenta RUT</option>
                    <option value="Otro">Otro</option>
                  </select>
                </div>
                <div><label class="label-style">Número de Cuenta *</label><input v-model="formData.bank.numero"
                    class="input-style" placeholder="1234567890" /></div>
              </div>
              <div v-if="formData.bank.tipo === 'Otro'"><label class="label-style">Especificar Tipo *</label><input
                  v-model="formData.bank.otroTipo" class="input-style" placeholder="Ej: Cuenta de Ahorro" /></div>

              <div class="mt-8 p-5 bg-blue-50 border-l-4 border-blue-900 rounded-r-xl">
                <h3 class="font-black text-blue-900 uppercase text-xs mb-2">4. Declaración del Trabajador [cite: 53-56]
                </h3>
                <p class="text-[10px] text-slate-600 leading-relaxed italic">
                  Declaro que la información proporcionada es verídica y que los antecedentes adjuntos son auténticos.
                  [cite: 54]
                  Autorizo a la empresa a remitir estos datos a la aseguradora. [cite: 56]
                </p>
                <div class="mt-4 text-[9px] font-bold text-slate-400 uppercase tracking-widest italic">Fecha de
                  Solicitud: {{ formData.fechaSolicitud }} [cite: 58]</div>
              </div>
            </div>
          </div>
        </div>

        <div
          class="bg-slate-50 p-6 flex flex-col md:flex-row items-center justify-between border-t border-slate-200 gap-4">

          <button v-if="currentStep > 1" @click="currentStep--"
            class="text-slate-400 font-bold uppercase text-xs tracking-widest hover:text-blue-900 transition-colors">
            ← Volver
          </button>
          <div v-else></div>

          <div class="flex gap-4 w-full md:w-auto">
            <button @click="saveAndExit" :disabled="saving || isLocked"
              class="flex-1 md:flex-none border-2 border-slate-200 text-slate-400 px-6 py-4 rounded-2xl font-black text-xs uppercase tracking-widest hover:bg-slate-100 transition-all">
              {{ saving ? '...' : 'Salir y seguir después' }}
            </button>

            <button @click="handleNavigation(currentStep === 3)" :disabled="saving || isLocked"
              class="flex-1 md:flex-none bg-blue-900 text-white px-10 py-4 rounded-2xl font-black shadow-xl hover:bg-blue-800 disabled:opacity-50 transition-all active:scale-95 text-xs uppercase tracking-widest">
              {{ saving ? 'PROCESANDO...' : (currentStep === 3 ? 'FINALIZAR ENVÍO' : 'GUARDAR Y SEGUIR') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <AlertDialogRoot v-model:open="isAlertOpen">
      <AlertDialogPortal>
        <AlertDialogOverlay class="bg-black/50 fixed inset-0 z-[100] backdrop-blur-sm" />
        <AlertDialogContent
          class="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white p-8 rounded-3xl shadow-2xl w-[90vw] max-w-md z-[101] outline-none">
          <AlertDialogTitle class="text-xl font-black text-slate-800 uppercase mb-2">{{ alertConfig.title }}
          </AlertDialogTitle>
          <AlertDialogDescription class="text-slate-500 mb-6 font-medium leading-relaxed italic">{{
            alertConfig.description }}</AlertDialogDescription>
          <div class="flex justify-end gap-4">
            <AlertDialogCancel v-if="alertConfig.isConfirm"
              class="px-6 py-3 font-bold text-slate-400 uppercase text-xs tracking-widest">CANCELAR</AlertDialogCancel>
            <AlertDialogAction @click="alertConfig.onAction"
              class="bg-blue-900 text-white px-8 py-3 rounded-xl font-black shadow-lg uppercase text-xs tracking-widest">
              {{ alertConfig.isConfirm ? 'CONFIRMAR' : 'ENTENDIDO' }}
            </AlertDialogAction>
          </div>
        </AlertDialogContent>
      </AlertDialogPortal>
    </AlertDialogRoot>
  </div>
</template>

<style scoped>
@reference "tailwindcss";

.label-style {
  @apply text-[10px] font-black text-slate-400 uppercase tracking-widest block mb-2 ml-1;
}

.input-style {
  @apply w-full bg-slate-50 border-2 border-slate-100 p-4 rounded-2xl focus:border-blue-900 focus:bg-white outline-none transition-all font-medium text-sm;
}
</style>