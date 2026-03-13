<script setup lang="ts">
/**
 * PANTALLA DE ACCESO - SEGURO P&B
 * Validación por RUT con algoritmo Módulo 11 y Gestión de Sesión JWT.
 */

const loginForm = reactive({ rut: '' }) 
const loading = ref(false)
const error = ref('')

// --- CONFIGURACIÓN DE COOKIES ---
const userId = useCookie('user_id')
const workerToken = useCookie('worker_token', { 
  maxAge: 60 * 60 * 24, // La sesión dura 24 horas para comodidad en terreno
  sameSite: 'lax'
})

// --- FUNCIÓN: VALIDACIÓN MATEMÁTICA (Módulo 11) ---
const validateRut = (rut: string) => {
  if (!rut || rut.length < 8) return false
  const cleaned = rut.replace(/[^0-9kK]/g, '').toUpperCase()
  if (cleaned.length < 8) return false
  const body = cleaned.slice(0, -1)
  const dv = cleaned.slice(-1)
  let sum = 0
  let multiplier = 2
  for (let i = body.length - 1; i >= 0; i--) {
    sum += parseInt(body[i]) * multiplier
    multiplier = multiplier === 7 ? 2 : multiplier + 1
  }
  const expectedRes = 11 - (sum % 11)
  const expectedDv = expectedRes === 11 ? '0' : expectedRes === 10 ? 'K' : expectedRes.toString()
  return expectedDv === dv
}

// --- FUNCIÓN: FORMATEO VISUAL ---
const formatRut = (value: string) => {
  if (!value) return ''
  let cleaned = value.replace(/[^0-9kK]/g, '').toUpperCase()
  if (cleaned.length <= 1) return cleaned
  let dv = cleaned.slice(-1)
  let body = cleaned.slice(0, -1)
  let formattedBody = body.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  return `${formattedBody}-${dv}`
}

watch(() => loginForm.rut, (newVal) => {
  loginForm.rut = formatRut(newVal)
})

async function enterForm() {
  if (!loginForm.rut) {
    return error.value = "Por favor, ingresa tu RUT para validar tu identidad."
  }

  if (!validateRut(loginForm.rut)) {
    return error.value = "El RUT ingresado no es válido. Revisa los dígitos."
  }
  
  loading.value = true
  error.value = ""
  
  try {
    const res: any = await $fetch('https://pybingenieriachile.cl/api-seguro/api/auth/login', { 
      method: 'POST', 
      body: { rut: loginForm.rut } 
    })
    
    // Validamos que el servidor nos entregue el Token y el Usuario
    if (res && res.token) {
      if (res.alreadySubmitted) {
        error.value = "Este RUT ya registra una evaluación finalizada."
        return
      }

      // 1. Guardamos el ID del usuario
      userId.value = res.user.id.toString()

      // 2. Guardamos el Token de seguridad
      workerToken.value = res.token

      // 3. Saltamos al formulario
      navigateTo('/formulario')
    }
  } catch (e: any) {
    error.value = "Error de conexión con el servidor de P&B. Intenta más tarde."
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 flex items-center justify-center p-4 font-sans text-slate-900">
    <div class="bg-white p-10 rounded-[2.5rem] shadow-2xl w-full max-w-md border-t-[12px] border-blue-900">
      <header class="text-center mb-10">
        <h1 class="text-4xl font-black text-slate-800 tracking-tighter italic uppercase">P&B Ingeniería</h1>
        <p class="text-blue-900 font-bold uppercase text-[10px] tracking-[0.2em] mt-2 opacity-80">
          Seguro Complementario de Salud
        </p>
      </header>

      <div class="space-y-6">
        <div>
          <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1 block mb-2">
            RUT del Trabajador
          </label>
          <input 
            v-model="loginForm.rut" 
            placeholder="12.345.678-9" 
            maxlength="12"
            class="w-full bg-slate-50 border-2 border-slate-100 p-4 rounded-2xl focus:border-blue-900 focus:bg-white outline-none transition-all font-bold text-slate-700 placeholder:font-normal placeholder:text-slate-300" 
            @keyup.enter="enterForm"
          />
        </div>
        
        <div v-if="error" class="bg-red-50 border-l-4 border-red-500 p-4 rounded-xl animate-in fade-in duration-300">
          <p class="text-red-700 text-xs font-black uppercase tracking-tight">{{ error }}</p>
        </div>

        <button 
          @click="enterForm" 
          :disabled="loading" 
          class="w-full bg-blue-900 text-white py-5 rounded-2xl font-black hover:bg-blue-800 active:scale-[0.98] transition-all shadow-xl disabled:opacity-50"
        >
          {{ loading ? 'VERIFICANDO...' : 'INGRESAR AL FORMULARIO' }}
        </button>

        <p class="text-center text-[9px] text-slate-400 font-bold uppercase tracking-widest mt-6 italic">
          USO EXCLUSIVO DEL TRABAJADOR
        </p>
      </div>
    </div>
  </div>
</template>