<script setup lang="ts">
import { 
  DialogRoot, DialogPortal, DialogOverlay, DialogContent, DialogTitle, DialogClose,
  AlertDialogRoot, AlertDialogPortal, AlertDialogOverlay, AlertDialogContent, AlertDialogTitle, AlertDialogDescription, AlertDialogAction, AlertDialogCancel 
} from 'reka-ui'

/**
 * PANEL DE GESTIÓN RR.HH. - P&B INGENIERÍA
 * Versión Final Pro: Campos condicionales, Selects, Paginación Backend y Alertas.
 */

// --- ESTADO DE SESIÓN ---
const loginForm = reactive({ rut: '', password: '' })
const authToken = useCookie('auth_token', { maxAge: 60 * 60 * 8 }) 
const authorized = ref(false)
const loading = ref(false)
const submissions = ref<any[]>([])
const error = ref('')

// --- ESTADO DE LISTADO (BACKEND) ---
const searchQuery = ref('')
const currentPage = ref(1)
const totalPages = ref(1)
const itemsPerPage = 8 

// --- ESTADO DE EDICIÓN Y ALERTAS ---
const isEditOpen = ref(false)
const editForm = ref<any>(null)
const savingEdit = ref(false)
const isConfirmOpen = ref(false)
const isSuccessOpen = ref(false)

// --- 1. ACCIONES DE DATOS ---

async function fetchSubmissions() {
  loading.value = true
  try {
    const res: any = await $fetch('https://pybingenieriachile.cl/api-seguro/api/admin/submissions', {
      params: { 
        page: currentPage.value, 
        limit: itemsPerPage,
        search: searchQuery.value 
      },
      headers: { Authorization: `Bearer ${authToken.value}` }
    })
    submissions.value = res.data
    totalPages.value = res.totalPages
    authorized.value = true
  } catch (e) {
    authorized.value = false
    authToken.value = null
  } finally {
    loading.value = false
  }
}

function triggerConfirm() {
  isConfirmOpen.value = true
}

async function executeUpdate() {
  isConfirmOpen.value = false
  savingEdit.value = true
  try {
    await $fetch(`https://pybingenieriachile.cl/api-seguro/api/admin/submissions/${editForm.value.id}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${authToken.value}` },
      body: editForm.value
    })
    isEditOpen.value = false
    isSuccessOpen.value = true
    await fetchSubmissions() 
  } catch (e: any) {
    alert("Error al actualizar: " + (e.data?.error || "Verifica la conexión"));
  } finally {
    savingEdit.value = false
  }
}

// --- 2. MANEJO DE BUSCADOR Y PÁGINAS ---

watch(currentPage, () => fetchSubmissions())

let searchTimeout: any
watch(searchQuery, () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    currentPage.value = 1
    fetchSubmissions()
  }, 500)
})

// --- 3. LOGIN Y UTILIDADES ---

async function checkAdmin() {
  if (!loginForm.rut || !loginForm.password) {
    error.value = "Ingresa RUT y Contraseña."
    return
  }
  loading.value = true; error.value = ""
  try {
    const res: any = await $fetch('https://pybingenieriachile.cl/api-seguro/api/auth/login-admin', {
      method: 'POST',
      body: loginForm
    })
    if (res.token) {
      authToken.value = res.token
      currentPage.value = 1
      await fetchSubmissions()
    }
  } catch (e) { error.value = "Credenciales incorrectas." }
  finally { loading.value = false }
}

const openEdit = (sub: any) => {
  editForm.value = JSON.parse(JSON.stringify(sub))
  isEditOpen.value = true
}

const formatRut = (v: string) => {
  let c = v.replace(/[^0-9kK]/g, '').toUpperCase()
  if (c.length <= 1) return c
  return c.slice(0, -1).replace(/\B(?=(\d{3})+(?!\d))/g, ".") + '-' + c.slice(-1)
}
watch(() => loginForm.rut, (n) => loginForm.rut = formatRut(n))

function downloadPDF(id: number) {
  window.open(`https://pybingenieriachile.cl/api-seguro/api/admin/generate-pdf/${id}?token=${authToken.value}`, '_blank')
}

function logout() { authToken.value = null; authorized.value = false; navigateTo('/') }

onMounted(() => { if (authToken.value) fetchSubmissions() })
</script>

<template>
  <div class="min-h-screen bg-slate-100 font-sans text-slate-900">

    <div v-if="!authorized" class="flex items-center justify-center min-h-screen p-4">
      <div class="bg-white p-10 rounded-[2.5rem] shadow-2xl w-full max-w-md border-t-[12px] border-blue-900">
        <header class="text-center mb-8">
          <h1 class="text-3xl font-black text-slate-800 italic uppercase tracking-tighter text-blue-900">P&B Admin</h1>
          <p class="text-slate-400 font-bold uppercase text-[10px] tracking-widest mt-2 opacity-80">Gestión Seguros RR.HH.</p>
        </header>
        <div class="space-y-4">
          <input v-model="loginForm.rut" placeholder="RUT Admin" maxlength="12" class="input-style" />
          <input v-model="loginForm.password" type="password" placeholder="Contraseña" class="input-style" @keyup.enter="checkAdmin" />
          <div v-if="error" class="bg-red-50 p-3 rounded-xl border-l-4 border-red-500 text-red-700 text-[10px] font-black uppercase">{{ error }}</div>
          <button @click="checkAdmin" :disabled="loading" class="btn-primary">ENTRAR AL PANEL</button>
        </div>
      </div>
    </div>

    <div v-else class="p-8 max-w-6xl mx-auto">
      <header class="flex flex-col lg:flex-row justify-between items-start lg:items-center mb-10 gap-6">
        <div>
          <h1 class="text-4xl font-black text-blue-900 italic uppercase tracking-tighter">Solicitudes</h1>
          <p class="text-slate-400 font-bold uppercase text-[10px] tracking-widest">Listado Maestro de Incorporaciones</p>
        </div>

        <div class="flex flex-col sm:flex-row items-center gap-4 w-full lg:w-auto">
          <div class="relative w-full sm:w-80">
            <input v-model="searchQuery" placeholder="Buscar por nombre o RUT..." class="w-full bg-white border-2 border-slate-200 pl-4 pr-4 py-3 rounded-2xl text-sm font-bold focus:border-blue-900 outline-none transition-all shadow-sm" />
          </div>
          <button @click="logout" class="bg-red-600 text-white px-6 py-3 rounded-2xl text-[10px] font-black uppercase hover:bg-red-700 shadow-lg transition-all active:scale-95 w-full sm:w-auto">
            Cerrar Sesión
          </button>
        </div>
      </header>

      <div class="bg-white rounded-[2.5rem] shadow-xl border border-slate-200 overflow-hidden relative">
        <div v-if="loading" class="absolute inset-0 bg-white/50 backdrop-blur-[1px] z-10 flex items-center justify-center font-black text-blue-900 text-[10px] uppercase tracking-widest animate-pulse">Sincronizando...</div>

        <table class="w-full text-left">
          <thead class="bg-slate-50 border-b border-slate-200 text-[10px] font-black text-slate-400 uppercase tracking-widest">
            <tr><th class="p-6 text-center">ID</th><th class="p-6">Trabajador</th><th class="p-6 text-center">Estado</th><th class="p-6 text-center">Acciones</th></tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="s in submissions" :key="s.id" class="hover:bg-blue-50/50 transition-colors">
              <td class="p-6 text-center text-slate-300 font-bold text-xs">{{ s.id }}</td>
              <td class="p-6 font-bold text-slate-700 uppercase text-sm">
                {{ s.workerName }}<br><span class="text-[13px] font-mono font-normal text-slate-600">{{ s.workerRut }}</span>
              </td>
              <td class="p-6 text-center">
                <span :class="s.status === 'submitted' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'" class="px-3 py-1 rounded-full text-[11px] font-black uppercase tracking-tighter">
                  {{ s.status === 'submitted' ? 'Recibido' : 'Borrador' }}
                </span>
              </td>
              <td class="p-6">
                <div class="flex justify-center gap-2">
                  <button @click="openEdit(s)" class="bg-slate-100 text-slate-600 px-4 py-2 rounded-lg text-[10px] font-black uppercase hover:bg-blue-900 hover:text-white transition-all">Ver Detalle</button>
                  <button v-if="s.status === 'submitted'" @click="downloadPDF(s.id)" class="bg-blue-900 text-white px-4 py-2 rounded-lg text-[10px] font-black uppercase shadow-lg hover:bg-blue-800 transition-all active:scale-95">descargar PDF</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <div class="bg-slate-50 p-6 flex justify-between items-center border-t border-slate-100">
          <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Página {{ currentPage }} de {{ totalPages }}</span>
          <div class="flex gap-2">
            <button @click="currentPage--" :disabled="currentPage === 1 || loading" class="btn-nav">Anterior</button>
            <button @click="currentPage++" :disabled="currentPage === totalPages || loading" class="btn-nav bg-blue-900 text-white border-blue-900">Siguiente</button>
          </div>
        </div>
      </div>
    </div>

    <DialogRoot v-model:open="isEditOpen">
      <DialogPortal>
        <DialogOverlay class="bg-black/60 fixed inset-0 z-[100] backdrop-blur-sm" />
        <DialogContent class="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-[2.5rem] shadow-2xl w-[95vw] max-w-5xl max-h-[90vh] z-[101] overflow-hidden flex flex-col outline-none border-t-[10px] border-blue-900">
          
          <header class="p-8 bg-white border-b flex justify-between items-center shrink-0">
            <div>
              <DialogTitle class="text-2xl font-black italic uppercase tracking-tighter text-blue-900">Expediente Digital #{{ editForm?.id }}</DialogTitle>
              <p class="text-slate-400 text-[10px] font-bold uppercase tracking-widest mt-1">Revisión y Edición de datos P&B</p>
            </div>
            <DialogClose class="bg-slate-100 p-2 rounded-full hover:bg-slate-200 transition-all text-slate-400">✕</DialogClose>
          </header>

          <div v-if="editForm" class="p-8 overflow-y-auto space-y-10 custom-scrollbar">
            
            <section>
              <h3 class="text-[10px] font-black text-blue-900 uppercase tracking-[0.2em] mb-6 border-b pb-2">1. Datos del Trabajador</h3>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div><label class="label-style">Nombre Completo</label><input v-model="editForm.workerName" placeholder="Ej: Juan Pérez" class="input-edit" /></div>
                <div><label class="label-style">RUT</label><input v-model="editForm.workerRut" placeholder="12.345.678-9" class="input-edit" /></div>
                <div><label class="label-style">Cargo Actual</label><input v-model="editForm.workerCargo" placeholder="Cargo en la empresa" class="input-edit" /></div>
                <div><label class="label-style">Área / Depto</label><input v-model="editForm.workerArea" placeholder="Ubicación laboral" class="input-edit" /></div>
                <div><label class="label-style">Email</label><input v-model="editForm.workerEmail" placeholder="correo@pyb.cl" class="input-edit" /></div>
                <div><label class="label-style">Teléfono</label><input v-model="editForm.workerPhone" placeholder="+56 9 ..." class="input-edit" /></div>
              </div>
            </section>

            <section>
              <h3 class="text-[10px] font-black text-blue-900 uppercase tracking-[0.2em] mb-6 border-b pb-2">2. Datos de la Carga</h3>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div class="md:col-span-2"><label class="label-style">Nombre Carga</label><input v-model="editForm.depName" placeholder="Nombre completo beneficiario" class="input-edit" /></div>
                <div><label class="label-style">RUT Carga</label><input v-model="editForm.depRut" placeholder="20.123.456-K" class="input-edit" /></div>
                <div><label class="label-style">Fec. Nacimiento</label><input v-model="editForm.depBirthDate" placeholder="DD/MM/AAAA" class="input-edit" /></div>
                <div><label class="label-style">Edad</label><input v-model="editForm.depAge" placeholder="00" class="input-edit" /></div>
                
                <div class="space-y-4">
                  <div>
                    <label class="label-style">Parentesco</label>
                    <select v-model="editForm.depRelationship" class="input-edit">
                      <option value="Cónyuge">Cónyuge</option>
                      <option value="Conviviente Civil">Conviviente Civil</option>
                      <option value="Hijo/a">Hijo/a</option>
                      <option value="Otro">Otro</option>
                    </select>
                  </div>
                  <div v-if="editForm.depRelationship === 'Otro'" class="animate-in fade-in slide-in-from-top-1">
                    <label class="label-style text-blue-600">Especificar Parentesco</label>
                    <input v-model="editForm.depOtherRel" placeholder="¿Cuál?" class="input-edit border-blue-200 bg-blue-50/30" />
                  </div>
                </div>

                <div class="space-y-4">
                  <div>
                    <label class="label-style">Sistema Salud</label>
                    <select v-model="editForm.depHealthSystem" class="input-edit">
                      <option value="Fonasa">Fonasa</option>
                      <option value="Isapre">Isapre</option>
                    </select>
                  </div>
                  <div v-if="editForm.depHealthSystem === 'Isapre'" class="animate-in fade-in slide-in-from-top-1">
                    <label class="label-style text-blue-600">Nombre Isapre</label>
                    <input v-model="editForm.depIsapreName" placeholder="Colmena, Consalud..." class="input-edit border-blue-200 bg-blue-50/30" />
                  </div>
                </div>
                
                <div><label class="label-style">Email Carga</label><input v-model="editForm.depEmail" placeholder="correo@ejemplo.com" class="input-edit" /></div>
              </div>
            </section>

            <section>
              <h3 class="text-[10px] font-black text-blue-900 uppercase tracking-[0.2em] mb-6 border-b pb-2">3. Información Bancaria</h3>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6 items-start">
                <div><label class="label-style">Banco</label><input v-model="editForm.bankName" placeholder="Ej: Banco Estado" class="input-edit" /></div>
                
                <div class="space-y-4">
                  <div>
                    <label class="label-style">Tipo de Cuenta</label>
                    <select v-model="editForm.bankAccountType" class="input-edit">
                      <option value="Cuenta Corriente">Cuenta Corriente</option>
                      <option value="Cuenta Vista">Cuenta Vista</option>
                      <option value="Cuenta RUT">Cuenta RUT</option>
                      <option value="Otro">Otro</option>
                    </select>
                  </div>
                  <div v-if="editForm.bankAccountType === 'Otro'" class="animate-in fade-in slide-in-from-top-1">
                    <label class="label-style text-blue-600">Especificar Tipo</label>
                    <input v-model="editForm.bankOtherType" placeholder="¿Qué tipo de cuenta?" class="input-edit border-blue-200 bg-blue-50/30" />
                  </div>
                </div>

                <div><label class="label-style">N° Cuenta</label><input v-model="editForm.bankAccountNumber" placeholder="Número de cuenta" class="input-edit" /></div>
              </div>
            </section>

            <section class="bg-slate-50 p-8 rounded-[2rem] border-2 border-dashed border-slate-200">
              <label class="label-style">Estado del Proceso</label>
              <select v-model="editForm.status" class="input-edit !bg-white">
                <option value="draft">Borrador (Incompleto)</option>
                <option value="submitted">Recibido (Finalizado)</option>
              </select>
            </section>
          </div>

          <footer class="p-8 bg-white border-t flex justify-end gap-4 shrink-0">
            <DialogClose class="px-8 py-4 font-black text-slate-400 uppercase text-[10px] tracking-widest">Cancelar</DialogClose>
            <button @click="triggerConfirm" :disabled="savingEdit" class="bg-blue-900 text-white px-10 py-4 rounded-2xl font-black shadow-xl uppercase text-[10px] tracking-widest hover:bg-blue-800 transition-all active:scale-95">
              Confirmar y Actualizar
            </button>
          </footer>
        </DialogContent>
      </DialogPortal>
    </DialogRoot>

    <AlertDialogRoot v-model:open="isConfirmOpen">
      <AlertDialogPortal>
        <AlertDialogOverlay class="bg-black/50 fixed inset-0 z-[120] backdrop-blur-sm" />
        <AlertDialogContent class="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white p-8 rounded-[2rem] shadow-2xl w-[90vw] max-w-md z-[121] outline-none border-b-8 border-amber-500">
          <AlertDialogTitle class="text-xl font-black text-slate-800 uppercase mb-2">¿Confirmar Modificación?</AlertDialogTitle>
          <AlertDialogDescription class="text-slate-500 mb-6 text-sm italic">Vas a sobreescribir datos del sistema. Esto alterará el PDF oficial de incorporación.</AlertDialogDescription>
          <div class="flex justify-end gap-4">
            <AlertDialogCancel class="px-6 py-3 font-bold text-slate-400 uppercase text-[10px]">No, volver</AlertDialogCancel>
            <AlertDialogAction @click="executeUpdate" class="bg-amber-500 text-white px-8 py-3 rounded-xl font-black uppercase text-[10px]">Sí, actualizar</AlertDialogAction>
          </div>
        </AlertDialogContent>
      </AlertDialogPortal>
    </AlertDialogRoot>

    <AlertDialogRoot v-model:open="isSuccessOpen">
      <AlertDialogPortal>
        <AlertDialogOverlay class="bg-black/50 fixed inset-0 z-[130] backdrop-blur-sm" />
        <AlertDialogContent class="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white p-8 rounded-[2rem] shadow-2xl w-[90vw] max-w-md z-[131] outline-none border-b-8 border-green-500 text-center">
          <div class="w-16 h-16 bg-green-100 text-green-600 rounded-full flex items-center justify-center mx-auto mb-4 font-black text-2xl">✓</div>
          <AlertDialogTitle class="text-xl font-black text-slate-800 uppercase mb-2">¡Completado!</AlertDialogTitle>
          <AlertDialogDescription class="text-slate-500 mb-6 text-sm font-medium">Los datos se han sincronizado correctamente con el servidor.</AlertDialogDescription>
          <AlertDialogAction class="bg-blue-900 text-white px-10 py-3 rounded-xl font-black uppercase text-[10px] w-full">Cerrar</AlertDialogAction>
        </AlertDialogContent>
      </AlertDialogPortal>
    </AlertDialogRoot>

  </div>
</template>

<style scoped>
@reference "tailwindcss";
.input-style { @apply w-full bg-slate-50 border-2 border-slate-100 p-4 rounded-2xl focus:border-blue-900 focus:bg-white outline-none font-bold text-slate-700; }
.btn-primary { @apply w-full bg-blue-900 text-white py-5 rounded-2xl font-black hover:bg-blue-800 transition-all shadow-xl disabled:opacity-50 uppercase text-xs; }
.btn-nav { @apply px-4 py-2 rounded-lg border-2 border-slate-200 text-[10px] font-black uppercase tracking-widest disabled:opacity-30 hover:bg-white transition-all shadow-sm; }
.input-edit { @apply w-full bg-white border-2 border-slate-200 p-3 rounded-xl focus:border-blue-900 outline-none font-medium text-sm transition-all; }
.input-edit::placeholder { @apply text-slate-300 font-normal italic; }
.label-style { @apply text-[9px] font-black text-slate-400 uppercase tracking-[0.1em] block mb-1 ml-1; }
.custom-scrollbar::-webkit-scrollbar { width: 6px; }
.custom-scrollbar::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 10px; }
</style>