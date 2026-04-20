import { useEffect, useMemo, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { Building2, RefreshCw, Plus, Trash2, Save, Users, HardDrive, Shield } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import {
  getSuperAdminStats,
  getSuperAdminTenants,
  createSuperAdminTenant,
  updateSuperAdminTenant,
  deleteSuperAdminTenant,
  getSuperAdminUsers,
  getSuperAdminTenantUsers,
  createSuperAdminTenantUser,
  updateSuperAdminTenantUserRole,
  deleteSuperAdminTenantUser,
  getSuperAdminTenantDevices,
} from '../api/client'

const emptyTenant = { slug: '', name: '', currency: 'USD' }
const emptyUser = { name: '', email: '', phone: '', password: '', role: 'user' }
const roles = ['user', 'admin', 'owner']

export default function SuperAdmin() {
  const { user, loading: authLoading } = useAuth()
  const [stats, setStats] = useState({ tenants: 0, users: 0, devices: 0 })
  const [tenants, setTenants] = useState([])
  const [allUsers, setAllUsers] = useState([])
  const [selectedId, setSelectedId] = useState('')
  const [tenantUsers, setTenantUsers] = useState([])
  const [tenantDevices, setTenantDevices] = useState([])
  const [tenantForm, setTenantForm] = useState(emptyTenant)
  const [editForm, setEditForm] = useState({ name: '', currency: 'USD', is_active: true })
  const [userForm, setUserForm] = useState(emptyUser)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const selectedTenant = useMemo(
    () => tenants.find(t => t.id === selectedId) || null,
    [tenants, selectedId],
  )

  const loadOverview = async () => {
    setLoading(true)
    setError('')
    try {
      const [statsRes, tenantsRes, usersRes] = await Promise.all([
        getSuperAdminStats(),
        getSuperAdminTenants(),
        getSuperAdminUsers(),
      ])
      const nextTenants = tenantsRes.data.tenants || []
      setStats(statsRes.data || {})
      setTenants(nextTenants)
      setAllUsers(usersRes.data.users || [])
      setSelectedId(current => current || nextTenants[0]?.id || '')
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Failed to load super admin data')
    } finally {
      setLoading(false)
    }
  }

  const loadTenantDetails = async (tenantId) => {
    if (!tenantId) {
      setTenantUsers([])
      setTenantDevices([])
      return
    }
    setError('')
    try {
      const [usersRes, devicesRes] = await Promise.all([
        getSuperAdminTenantUsers(tenantId),
        getSuperAdminTenantDevices(tenantId),
      ])
      setTenantUsers(usersRes.data.users || [])
      setTenantDevices(devicesRes.data.devices || [])
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Failed to load tenant details')
    }
  }

  useEffect(() => {
    if (user?.role === 'superadmin') loadOverview()
  }, [user?.role])

  useEffect(() => {
    if (selectedTenant) {
      setEditForm({
        name: selectedTenant.name || '',
        currency: selectedTenant.currency || 'USD',
        is_active: !!selectedTenant.is_active,
      })
      loadTenantDetails(selectedTenant.id)
    }
  }, [selectedTenant?.id])

  if (authLoading) return null
  if (user?.role !== 'superadmin') return <Navigate to="/" replace />

  const showMessage = (message) => {
    setSuccess(message)
    window.setTimeout(() => setSuccess(''), 2500)
  }

  const createTenant = async (e) => {
    e.preventDefault()
    setSaving(true)
    setError('')
    try {
      const res = await createSuperAdminTenant({
        slug: tenantForm.slug.trim(),
        name: tenantForm.name.trim(),
        currency: tenantForm.currency.trim().toUpperCase(),
      })
      setTenantForm(emptyTenant)
      showMessage('Tenant created.')
      await loadOverview()
      setSelectedId(res.data.id)
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Failed to create tenant')
    } finally {
      setSaving(false)
    }
  }

  const saveTenant = async () => {
    if (!selectedTenant) return
    setSaving(true)
    setError('')
    try {
      await updateSuperAdminTenant(selectedTenant.id, {
        name: editForm.name.trim(),
        currency: editForm.currency.trim().toUpperCase(),
        is_active: editForm.is_active,
      })
      showMessage('Tenant updated.')
      await loadOverview()
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Failed to update tenant')
    } finally {
      setSaving(false)
    }
  }

  const removeTenant = async (tenant) => {
    if (!window.confirm(`Remove tenant "${tenant.name}" and its users/devices?`)) return
    setSaving(true)
    setError('')
    try {
      await deleteSuperAdminTenant(tenant.id)
      showMessage('Tenant removed.')
      setSelectedId('')
      await loadOverview()
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Failed to remove tenant')
    } finally {
      setSaving(false)
    }
  }

  const createUser = async (e) => {
    e.preventDefault()
    if (!selectedTenant) return
    setSaving(true)
    setError('')
    try {
      await createSuperAdminTenantUser(selectedTenant.id, {
        name: userForm.name.trim(),
        email: userForm.email.trim(),
        phone: userForm.phone.trim() || null,
        password: userForm.password,
        role: userForm.role,
      })
      setUserForm(emptyUser)
      showMessage('User created.')
      await Promise.all([loadTenantDetails(selectedTenant.id), loadOverview()])
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Failed to create user')
    } finally {
      setSaving(false)
    }
  }

  const changeRole = async (targetUser, role) => {
    if (!selectedTenant) return
    setError('')
    try {
      await updateSuperAdminTenantUserRole(selectedTenant.id, targetUser.id, role)
      await Promise.all([loadTenantDetails(selectedTenant.id), loadOverview()])
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Failed to update user role')
    }
  }

  const removeUser = async (targetUser) => {
    if (!selectedTenant) return
    if (!window.confirm(`Remove user "${targetUser.name}" from ${selectedTenant.name}?`)) return
    setError('')
    try {
      await deleteSuperAdminTenantUser(selectedTenant.id, targetUser.id)
      await Promise.all([loadTenantDetails(selectedTenant.id), loadOverview()])
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Failed to remove user')
    }
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Super Admin</h1>
          <p className="text-sm text-gray-500 mt-1">Manage all tenants, company users, and assigned devices.</p>
        </div>
        <button
          onClick={loadOverview}
          className="inline-flex items-center gap-2 px-3 py-2 text-sm bg-white border border-gray-200 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {error && <div className="px-4 py-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">{error}</div>}
      {success && <div className="px-4 py-3 bg-green-50 border border-green-200 text-green-700 rounded-lg text-sm">{success}</div>}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Stat icon={Building2} label="Active Tenants" value={stats.tenants || 0} />
        <Stat icon={Users} label="Company Users" value={stats.users || 0} />
        <Stat icon={HardDrive} label="Assigned Devices" value={stats.devices || 0} />
      </div>

      <form onSubmit={createTenant} className="bg-white border border-gray-200 rounded-xl p-5">
        <div className="flex items-center gap-2 mb-4">
          <Plus size={18} className="text-brand-600" />
          <h2 className="font-semibold text-gray-900">Add Tenant</h2>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-[1fr_1fr_120px_auto] gap-3">
          <Input label="Slug" value={tenantForm.slug} onChange={v => setTenantForm(f => ({ ...f, slug: v }))} placeholder="company-slug" required />
          <Input label="Name" value={tenantForm.name} onChange={v => setTenantForm(f => ({ ...f, name: v }))} placeholder="Company Name" required />
          <Input label="Currency" value={tenantForm.currency} onChange={v => setTenantForm(f => ({ ...f, currency: v }))} maxLength={3} required />
          <div className="flex items-end">
            <button disabled={saving} className="inline-flex items-center gap-2 px-4 py-2 bg-brand-600 text-white rounded-lg text-sm font-medium hover:bg-brand-700 disabled:opacity-50">
              <Plus size={16} /> Add
            </button>
          </div>
        </div>
      </form>

      <div className="grid grid-cols-1 xl:grid-cols-[360px_1fr] gap-6">
        <div className="bg-white border border-gray-200 rounded-xl overflow-hidden">
          <div className="px-4 py-3 border-b border-gray-100 font-semibold text-gray-900">Tenants</div>
          <div className="divide-y divide-gray-100 max-h-[620px] overflow-y-auto">
            {loading ? (
              <div className="px-4 py-8 text-sm text-gray-400 text-center">Loading tenants...</div>
            ) : tenants.length === 0 ? (
              <div className="px-4 py-8 text-sm text-gray-400 text-center">No tenants yet.</div>
            ) : tenants.map(tenant => (
              <button
                type="button"
                key={tenant.id}
                onClick={() => setSelectedId(tenant.id)}
                className={`w-full text-left px-4 py-3 hover:bg-gray-50 ${selectedId === tenant.id ? 'bg-brand-50' : ''}`}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="font-medium text-gray-900 truncate">{tenant.name}</p>
                    <p className="text-xs text-gray-500 truncate">{tenant.slug}</p>
                  </div>
                  <span className={`text-[10px] px-2 py-0.5 rounded-full ${tenant.is_active ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                    {tenant.is_active ? 'active' : 'inactive'}
                  </span>
                </div>
                <div className="text-xs text-gray-400 mt-2">{tenant.user_count || 0} users - {tenant.device_count || 0} devices</div>
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-6">
          {selectedTenant ? (
            <>
              <section className="bg-white border border-gray-200 rounded-xl p-5">
                <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
                  <div className="grid grid-cols-1 md:grid-cols-[1fr_120px_130px] gap-3 flex-1">
                    <Input label="Tenant Name" value={editForm.name} onChange={v => setEditForm(f => ({ ...f, name: v }))} />
                    <Input label="Currency" value={editForm.currency} onChange={v => setEditForm(f => ({ ...f, currency: v }))} maxLength={3} />
                    <label className="flex items-center gap-2 text-sm text-gray-700 pb-2">
                      <input
                        type="checkbox"
                        checked={editForm.is_active}
                        onChange={e => setEditForm(f => ({ ...f, is_active: e.target.checked }))}
                        className="rounded border-gray-300 text-brand-600 focus:ring-brand-500"
                      />
                      Active
                    </label>
                  </div>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={saveTenant}
                      disabled={saving}
                      className="inline-flex items-center gap-2 px-4 py-2 bg-brand-600 text-white rounded-lg text-sm font-medium hover:bg-brand-700 disabled:opacity-50"
                    >
                      <Save size={16} /> Save
                    </button>
                    <button
                      type="button"
                      onClick={() => removeTenant(selectedTenant)}
                      disabled={saving}
                      className="inline-flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg text-sm font-medium hover:bg-red-700 disabled:opacity-50"
                    >
                      <Trash2 size={16} /> Remove
                    </button>
                  </div>
                </div>
                <p className="text-xs text-gray-400 mt-3">Tenant ID: {selectedTenant.id}</p>
              </section>

              <section className="bg-white border border-gray-200 rounded-xl p-5">
                <div className="flex items-center gap-2 mb-4">
                  <Shield size={18} className="text-brand-600" />
                  <h2 className="font-semibold text-gray-900">Add User To {selectedTenant.name}</h2>
                </div>
                <form onSubmit={createUser} className="grid grid-cols-1 md:grid-cols-3 gap-3">
                  <Input label="Name" value={userForm.name} onChange={v => setUserForm(f => ({ ...f, name: v }))} required />
                  <Input label="Email" type="email" value={userForm.email} onChange={v => setUserForm(f => ({ ...f, email: v }))} required />
                  <Input label="Phone" value={userForm.phone} onChange={v => setUserForm(f => ({ ...f, phone: v }))} />
                  <Input label="Password" type="password" value={userForm.password} onChange={v => setUserForm(f => ({ ...f, password: v }))} required minLength={6} />
                  <div>
                    <label className="block text-xs font-semibold text-gray-500 mb-1">Role</label>
                    <select
                      value={userForm.role}
                      onChange={e => setUserForm(f => ({ ...f, role: e.target.value }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-brand-500"
                    >
                      {roles.map(role => <option key={role} value={role}>{role}</option>)}
                    </select>
                  </div>
                  <div className="flex items-end">
                    <button disabled={saving} className="inline-flex items-center gap-2 px-4 py-2 bg-brand-600 text-white rounded-lg text-sm font-medium hover:bg-brand-700 disabled:opacity-50">
                      <Plus size={16} /> Add User
                    </button>
                  </div>
                </form>
              </section>

              <section className="bg-white border border-gray-200 rounded-xl overflow-hidden">
                <div className="px-4 py-3 border-b border-gray-100 font-semibold text-gray-900">Tenant Users</div>
                <UsersTable users={tenantUsers} onRoleChange={changeRole} onRemove={removeUser} showTenant={false} />
              </section>

              <section className="bg-white border border-gray-200 rounded-xl overflow-hidden">
                <div className="px-4 py-3 border-b border-gray-100 font-semibold text-gray-900">Tenant Devices</div>
                <DevicesTable devices={tenantDevices} />
              </section>
            </>
          ) : (
            <div className="bg-white border border-gray-200 rounded-xl px-4 py-10 text-center text-gray-400">Select a tenant.</div>
          )}
        </div>
      </div>

      <section className="bg-white border border-gray-200 rounded-xl overflow-hidden">
        <div className="px-4 py-3 border-b border-gray-100 font-semibold text-gray-900">All Company Users</div>
        <UsersTable users={allUsers} showTenant />
      </section>
    </div>
  )
}

function Stat({ icon: Icon, label, value }) {
  return (
    <div className="bg-white border border-gray-200 rounded-xl p-5">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-500">{label}</p>
          <p className="text-3xl font-bold text-gray-900 mt-1">{value}</p>
        </div>
        <div className="w-11 h-11 rounded-lg bg-brand-50 text-brand-600 flex items-center justify-center">
          <Icon size={22} />
        </div>
      </div>
    </div>
  )
}

function Input({ label, value, onChange, ...props }) {
  return (
    <div>
      <label className="block text-xs font-semibold text-gray-500 mb-1">{label}</label>
      <input
        value={value}
        onChange={e => onChange(e.target.value)}
        className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        {...props}
      />
    </div>
  )
}

function UsersTable({ users, onRoleChange, onRemove, showTenant }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className="bg-gray-50 text-gray-600">
          <tr>
            <th className="text-left px-4 py-3 font-semibold">User</th>
            {showTenant && <th className="text-left px-4 py-3 font-semibold">Tenant</th>}
            <th className="text-left px-4 py-3 font-semibold">Role</th>
            <th className="text-left px-4 py-3 font-semibold">Joined</th>
            {onRemove && <th className="px-4 py-3 w-24"></th>}
          </tr>
        </thead>
        <tbody>
          {users.length === 0 ? (
            <tr>
              <td colSpan={showTenant ? 5 : 4} className="px-4 py-8 text-center text-gray-400">No users found.</td>
            </tr>
          ) : users.map(user => (
            <tr key={user.id} className="border-t border-gray-100">
              <td className="px-4 py-3">
                <div className="font-medium text-gray-800">{user.name}</div>
                <div className="text-xs text-gray-500">{user.email}</div>
              </td>
              {showTenant && (
                <td className="px-4 py-3">
                  <div className="text-gray-800">{user.tenant_name || 'No tenant'}</div>
                  <div className="text-xs text-gray-500">{user.tenant_slug || user.tenant_id || ''}</div>
                </td>
              )}
              <td className="px-4 py-3">
                {onRoleChange ? (
                  <select
                    value={user.role}
                    onChange={e => onRoleChange(user, e.target.value)}
                    className="text-xs px-2 py-1 rounded-md border border-gray-200 bg-white focus:outline-none focus:ring-1 focus:ring-brand-500"
                  >
                    {roles.map(role => <option key={role} value={role}>{role}</option>)}
                  </select>
                ) : (
                  <span className="inline-flex text-xs font-medium px-2 py-0.5 rounded-full bg-gray-100 text-gray-700">{user.role}</span>
                )}
              </td>
              <td className="px-4 py-3 text-gray-500">{user.created_at ? new Date(user.created_at).toLocaleDateString() : '-'}</td>
              {onRemove && (
                <td className="px-4 py-3 text-right">
                  <button onClick={() => onRemove(user)} className="inline-flex items-center gap-1 text-red-600 hover:text-red-700 text-xs font-medium">
                    <Trash2 size={14} /> Remove
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function DevicesTable({ devices }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className="bg-gray-50 text-gray-600">
          <tr>
            <th className="text-left px-4 py-3 font-semibold">Device ID</th>
            <th className="text-left px-4 py-3 font-semibold">Name</th>
            <th className="text-left px-4 py-3 font-semibold">Assigned</th>
          </tr>
        </thead>
        <tbody>
          {devices.length === 0 ? (
            <tr>
              <td colSpan="3" className="px-4 py-8 text-center text-gray-400">No devices assigned.</td>
            </tr>
          ) : devices.map(device => (
            <tr key={device.device_id} className="border-t border-gray-100">
              <td className="px-4 py-3 font-mono text-gray-800">{device.device_id}</td>
              <td className="px-4 py-3 text-gray-700">{device.device_name || '-'}</td>
              <td className="px-4 py-3 text-gray-500">{device.created_at ? new Date(device.created_at).toLocaleString() : '-'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
