import { createClient } from 'npm:@supabase/supabase-js@2'

type CreateEmployeeRequest = {
  email?: string
  password?: string
  employeeId?: string
  fullName?: string
  jobTitle?: string | null
  departmentId?: string | null
  usualOfficeLocationId?: string | null
  supervisorId?: string | null
  roles?: string[]
  isActive?: boolean
}

const allowedRoles = new Set(['employee', 'supervisor', 'hr', 'admin'])
const jsonHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: jsonHeaders })
  }
  if (request.method !== 'POST') {
    return response({ error: 'Method not allowed.' }, 405)
  }

  const authorization = request.headers.get('Authorization')
  if (!authorization) {
    return response({ error: 'Authentication is required.' }, 401)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  })
  const adminClient = createClient(supabaseUrl, serviceRoleKey)

  const { data: userData, error: userError } = await callerClient.auth.getUser()
  const caller = userData.user
  if (userError || !caller) {
    return response({ error: 'Your session is no longer valid.' }, 401)
  }

  const { data: callerRoles, error: roleError } = await adminClient
    .from('profile_roles')
    .select('role')
    .eq('profile_id', caller.id)
  if (roleError) {
    return response({ error: 'Unable to verify employee-management access.' }, 500)
  }

  const roles = new Set((callerRoles ?? []).map((row) => String(row.role)))
  const isAdmin = roles.has('admin')
  const isHr = roles.has('hr')
  if (!isAdmin && !isHr) {
    return response({ error: 'Only HR and administrators can create employees.' }, 403)
  }

  const { data: callerProfile, error: callerProfileError } = await adminClient
    .from('profiles')
    .select('is_active')
    .eq('id', caller.id)
    .maybeSingle()
  if (callerProfileError || !callerProfile?.is_active) {
    return response({ error: 'Your employee-management access is inactive.' }, 403)
  }

  let payload: CreateEmployeeRequest
  try {
    payload = await request.json() as CreateEmployeeRequest
  } catch (_) {
    return response({ error: 'The employee details are invalid.' }, 400)
  }

  const email = payload.email?.trim().toLowerCase() ?? ''
  const password = payload.password ?? ''
  const employeeId = payload.employeeId?.trim() ?? ''
  const fullName = payload.fullName?.trim() ?? ''
  const jobTitle = blankToNull(payload.jobTitle)
  const requestedRoles = normalizeRoles(payload.roles)

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return response({ error: 'Enter a valid employee email address.' }, 400)
  }
  if (password.length < 8) {
    return response({ error: 'The temporary password must contain at least 8 characters.' }, 400)
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9._/-]{1,39}$/.test(employeeId)) {
    return response({ error: 'Employee ID contains unsupported characters.' }, 400)
  }
  if (fullName.length < 2 || fullName.length > 120) {
    return response({ error: 'Full name must contain between 2 and 120 characters.' }, 400)
  }
  if (jobTitle && (jobTitle.length < 2 || jobTitle.length > 120)) {
    return response({ error: 'Job title must contain between 2 and 120 characters.' }, 400)
  }
  if (!isAdmin && requestedRoles.some((role) => role !== 'employee')) {
    return response({ error: 'Only administrators can grant access roles.' }, 403)
  }

  const referenceError = await validateReferences(adminClient, payload)
  if (referenceError) {
    return response({ error: referenceError }, 400)
  }

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      employee_id: employeeId,
      full_name: fullName,
      role: highestRole(requestedRoles),
    },
  })
  if (createError || !created.user) {
    const duplicate = createError?.message.toLowerCase().includes('already') ?? false
    return response({
      error: duplicate
        ? 'An account already exists for this email address.'
        : createError?.message ?? 'Unable to create the employee account.',
    }, duplicate ? 409 : 400)
  }

  const profileId = created.user.id
  try {
    const { error: profileError } = await adminClient
      .from('profiles')
      .update({
        employee_id: employeeId,
        full_name: fullName,
        email,
        job_title: jobTitle,
        department_id: payload.departmentId ?? null,
        department: await departmentName(adminClient, payload.departmentId),
        usual_office_location_id: payload.usualOfficeLocationId ?? null,
        role: highestRole(requestedRoles),
        is_active: payload.isActive ?? true,
        updated_at: new Date().toISOString(),
      })
      .eq('id', profileId)
    if (profileError) throw profileError

    const { error: deleteRoleError } = await adminClient
      .from('profile_roles')
      .delete()
      .eq('profile_id', profileId)
    if (deleteRoleError) throw deleteRoleError

    const { error: insertRoleError } = await adminClient
      .from('profile_roles')
      .insert(requestedRoles.map((role) => ({
        profile_id: profileId,
        role,
        assigned_by: caller.id,
      })))
    if (insertRoleError) throw insertRoleError

    if (payload.supervisorId) {
      const { error: assignmentError } = await adminClient
        .from('employee_supervisor_assignments')
        .insert({
          employee_id: profileId,
          supervisor_id: payload.supervisorId,
          is_primary: true,
          is_active: true,
          effective_from: new Date().toISOString().slice(0, 10),
          created_by: caller.id,
        })
      if (assignmentError) throw assignmentError
    }
  } catch (error) {
    await adminClient.auth.admin.deleteUser(profileId)
    console.error('Employee onboarding rolled back', error)
    return response({ error: databaseErrorMessage(error) }, 400)
  }

  return response({ id: profileId, message: 'Employee account created.' }, 201)
})

function normalizeRoles(input?: string[]): string[] {
  const roles = new Set(['employee'])
  for (const role of input ?? []) {
    if (allowedRoles.has(role)) roles.add(role)
  }
  return ['employee', 'supervisor', 'hr', 'admin'].filter((role) => roles.has(role))
}

function highestRole(roles: string[]): string {
  if (roles.includes('admin')) return 'admin'
  if (roles.includes('hr')) return 'hr'
  if (roles.includes('supervisor')) return 'supervisor'
  return 'employee'
}

function blankToNull(value?: string | null): string | null {
  const trimmed = value?.trim() ?? ''
  return trimmed.length === 0 ? null : trimmed
}

async function validateReferences(client: ReturnType<typeof createClient>, payload: CreateEmployeeRequest) {
  if (payload.departmentId) {
    const { data } = await client.from('departments').select('id').eq('id', payload.departmentId).eq('is_active', true).maybeSingle()
    if (!data) return 'Select an active department.'
  }
  const jobTitle = blankToNull(payload.jobTitle)
  if (!jobTitle) return 'Select a job title.'
  const { data: jobTitleRow } = await client
    .from('job_titles')
    .select('id')
    .eq('name', jobTitle)
    .eq('is_active', true)
    .maybeSingle()
  if (!jobTitleRow) return 'Select an active job title.'
  if (payload.usualOfficeLocationId) {
    const { data } = await client.from('office_locations').select('id').eq('id', payload.usualOfficeLocationId).eq('is_active', true).maybeSingle()
    if (!data) return 'Select an active usual office.'
  }
  if (payload.supervisorId) {
    const { data: supervisor } = await client.from('profiles').select('id, is_active').eq('id', payload.supervisorId).eq('is_active', true).maybeSingle()
    const { data: supervisorRole } = await client.from('profile_roles').select('role').eq('profile_id', payload.supervisorId).eq('role', 'supervisor').maybeSingle()
    if (!supervisor || !supervisorRole) return 'Select an active supervisor.'
  }
  return null
}

async function departmentName(client: ReturnType<typeof createClient>, id?: string | null) {
  if (!id) return null
  const { data } = await client.from('departments').select('name').eq('id', id).maybeSingle()
  return data?.name ?? null
}

function databaseErrorMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error)
  if (message.includes('profiles_employee_id_key') || message.includes('duplicate key')) {
    return 'That employee ID is already in use.'
  }
  return message || 'Unable to finish creating the employee account.'
}

function response(body: Record<string, unknown>, status: number) {
  return Response.json(body, { status, headers: jsonHeaders })
}
