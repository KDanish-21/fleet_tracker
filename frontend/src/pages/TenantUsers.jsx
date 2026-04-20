import { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { Trash2, Plus, RefreshCw, Shield } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { getUsers, inviteUser, updateUserRole, deleteUser } from '../api/client'

const ROLES_ALLOWED = new Set(['owner', 'admin'])
const ROLE_OPTIONS = ['user', 'admin', 'owner']

const ROLE_BADGE = {
  owner: 'bg-purple-100 text-purple-700',
  admin: 'bg-blue-100 text-blue-700',
  user:  'bg-gray-100 text-gray-600',
}

const emptyForm = { name: '', email: '', phone: '', password: '', role: 'user' }

export default function TenantUsers() {
  const { user: me, loading: authLoading } = useAuth()
  const [users, setUsers]     = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError]     = useState('')
  const [form, setForm]       = useState(emptyForm)
  const [submitting, setSubmitting] = useState(false)
  const [showForm, setShowForm] = useState(false)

  const isOwner = me?.role === 'owner'
  const allowed = !!me?.role && ROLES_ALLOWED.has(me.role)

  const load = async () => {
    setLoading(true)
    setError('')
    try {
      const res = await getUsers()
      setUsers(res.data.users || [])
    } catch (e) {
      setError(e?.response?.data?.detail || e.message || 'Failed to load users')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { if (allowed) load() }, [allowed])

  if (authLoading) return null
  if (!allowed) return <Navigate to="/" replace />

  const onChange = (k, v) => setForm(f => ({ ...f, [k]: v }))

  const onInvite = async (e) => {
    e.preventDefault()
    setSubmitting(true)
    setError('')
    try {
      await inviteUser({
        name: form.name.trim(),
        email: form.email.trim(),
        phone: form.phone.trim() || null,
        password: form.password,
        role: form.role,
      })
      setForm(emptyForm)
      setShowForm(false)
      await load()
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Invite failed')
    } finally {
      setSubmitting(false)
    }
  }

  const onRoleChange = async (userId, newRole) => {
    setError('')
    try {
      const res = await updateUserRole(userId, newRole)
      setUsers(us => us.map(u => u.id === userId ? res.data.user : u))
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Role update failed')
    }
  }

  const onDelete = async (userId, name) => {
    if (!window.confirm(`Remove user "${name}" from this workspace?`)) return
    setError('')
    try {
      await deleteUser(userId)
      setUsers(us => us.filter(u => u.id !== userId))
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Delete failed')
    }
  }

  const canChangeRole = (target) => isOwner || (me?.role === 'admin' && target.role !== 'owner')
  const canDelete = (target) =>
    target.id !== me?.id &&
    (isOwner || (me?.role === 'admin' && target.role !== 'owner'))

  return (
    <div className="max-w-5xl mx-auto">
      <div className="flex items-center justify-between mb-5">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Workspace Users</h1>
          <p className="text-sm text-gray-500 mt-1">
            Manage who has access to this workspace and their roles.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={load}
            className="flex items-center gap-2 px-3 py-2 text-sm bg-white border border-gray-200 rounded-lg hover:bg-gray-50"
          >
            <RefreshCw size={14} /> Refresh
          </button>
          {allowed && (
            <button
              onClick={() => setShowForm(f => !f)}
              className="flex items-center gap-2 px-4 py-2 text-sm bg-brand-600 text-white rounded-lg font-medium hover:bg-brand-700"
            >
              <Plus size={16} /> Invite User
            </button>
          )}
        </div>
      </div>

      {showForm && (
        <form
          onSubmit={onInvite}
          className="bg-white border border-gray-200 rounded-xl p-5 mb-6 grid grid-cols-1 md:grid-cols-2 gap-4"
        >
          <div>
            <label className="block text-xs font-semibold text-gray-500 mb-1">Full Name</label>
            <input
              required
              value={form.name}
              onChange={e => onChange('name', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              placeholder="Jane Smith"
            />
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 mb-1">Email</label>
            <input
              required
              type="email"
              value={form.email}
              onChange={e => onChange('email', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              placeholder="jane@company.com"
            />
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 mb-1">Phone (optional)</label>
            <input
              value={form.phone}
              onChange={e => onChange('phone', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              placeholder="+255 ..."
            />
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 mb-1">Temporary Password</label>
            <input
              required
              type="password"
              minLength={6}
              value={form.password}
              onChange={e => onChange('password', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              placeholder="Min 6 characters"
            />
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 mb-1">Role</label>
            <select
              value={form.role}
              onChange={e => onChange('role', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 bg-white"
            >
              {ROLE_OPTIONS.filter(r => r !== 'owner' || isOwner).map(r => (
                <option key={r} value={r}>{r.charAt(0).toUpperCase() + r.slice(1)}</option>
              ))}
            </select>
          </div>
          <div className="md:col-span-2 flex items-center gap-3">
            <button
              type="submit"
              disabled={submitting}
              className="flex items-center gap-2 px-4 py-2 bg-brand-600 text-white rounded-lg text-sm font-medium hover:bg-brand-700 disabled:opacity-50"
            >
              <Plus size={16} /> {submitting ? 'Creating...' : 'Create User'}
            </button>
            <button
              type="button"
              onClick={() => { setShowForm(false); setForm(emptyForm) }}
              className="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      {error && (
        <div className="mb-4 px-4 py-2.5 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="bg-white border border-gray-200 rounded-xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-600">
            <tr>
              <th className="text-left px-4 py-3 font-semibold">User</th>
              <th className="text-left px-4 py-3 font-semibold">Role</th>
              <th className="text-left px-4 py-3 font-semibold">Joined</th>
              <th className="px-4 py-3 w-24"></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan="4" className="px-4 py-8 text-center text-gray-400">Loading users...</td>
              </tr>
            ) : users.length === 0 ? (
              <tr>
                <td colSpan="4" className="px-4 py-8 text-center text-gray-400">No users found.</td>
              </tr>
            ) : (
              users.map(u => (
                <tr key={u.id} className="border-t border-gray-100">
                  <td className="px-4 py-3">
                    <div className="font-medium text-gray-800 flex items-center gap-1.5">
                      {u.name}
                      {u.id === me?.id && (
                        <span className="text-[10px] bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded">you</span>
                      )}
                    </div>
                    <div className="text-xs text-gray-500">{u.email}</div>
                  </td>
                  <td className="px-4 py-3">
                    {canChangeRole(u) && u.id !== me?.id ? (
                      <select
                        value={u.role}
                        onChange={e => onRoleChange(u.id, e.target.value)}
                        className="text-xs px-2 py-1 rounded-md border border-gray-200 bg-white focus:outline-none focus:ring-1 focus:ring-brand-500"
                      >
                        {ROLE_OPTIONS.filter(r => r !== 'owner' || isOwner).map(r => (
                          <option key={r} value={r}>{r.charAt(0).toUpperCase() + r.slice(1)}</option>
                        ))}
                      </select>
                    ) : (
                      <span className={`inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full ${ROLE_BADGE[u.role] || ROLE_BADGE.user}`}>
                        {u.role === 'owner' && <Shield size={10} />}
                        {u.role}
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-gray-500">
                    {u.created_at ? new Date(u.created_at).toLocaleDateString() : '—'}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {canDelete(u) && (
                      <button
                        onClick={() => onDelete(u.id, u.name)}
                        className="inline-flex items-center gap-1 text-red-600 hover:text-red-700 text-xs font-medium"
                      >
                        <Trash2 size={14} /> Remove
                      </button>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
