import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { User, Mail, Phone, Calendar, LogOut, Shield, Lock, Save } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { updateProfile, changePassword } from '../api/client'

const ROLE_BADGE = {
  owner: 'bg-purple-100 text-purple-700',
  admin: 'bg-blue-100 text-blue-700',
  user:  'bg-gray-100 text-gray-600',
}

export default function Profile() {
  const { user, logout, setUser } = useAuth()
  const navigate = useNavigate()
  const [tab, setTab] = useState('info')

  const handleLogout = () => { logout(); navigate('/login') }
  if (!user) return null

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Profile</h1>

      {/* Avatar + role */}
      <div className="bg-white border border-gray-200 rounded-xl p-6 flex items-center gap-5">
        <div className="w-16 h-16 rounded-2xl bg-brand-100 flex items-center justify-center flex-shrink-0">
          <User size={30} className="text-brand-600" />
        </div>
        <div className="flex-1 min-w-0">
          <h2 className="text-lg font-bold text-gray-900 truncate">{user.name}</h2>
          <p className="text-sm text-gray-500 truncate">{user.email}</p>
          <span className={`inline-flex items-center gap-1 mt-2 px-2 py-0.5 text-xs font-medium rounded-full ${ROLE_BADGE[user.role] || ROLE_BADGE.user}`}>
            <Shield size={10} /> {user.role}
          </span>
        </div>
        <button
          onClick={handleLogout}
          className="flex items-center gap-2 px-3 py-2 text-sm text-red-600 border border-red-200 rounded-lg hover:bg-red-50"
        >
          <LogOut size={14} /> Sign out
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 border-b border-gray-200">
        {[['info', 'Edit Profile'], ['password', 'Change Password']].map(([id, label]) => (
          <button
            key={id}
            onClick={() => setTab(id)}
            className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
              tab === id
                ? 'border-brand-600 text-brand-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === 'info'
        ? <EditProfileForm user={user} />
        : <ChangePasswordForm />
      }
    </div>
  )
}

function EditProfileForm({ user }) {
  const { refreshUser } = useAuth()
  const [form, setForm]     = useState({ name: user.name || '', phone: user.phone || '' })
  const [saving, setSaving] = useState(false)
  const [error, setError]   = useState('')
  const [success, setSuccess] = useState('')

  const onSubmit = async (e) => {
    e.preventDefault()
    setSaving(true); setError(''); setSuccess('')
    try {
      await updateProfile({ name: form.name.trim(), phone: form.phone.trim() || null })
      setSuccess('Profile updated.')
      refreshUser && await refreshUser()
    } catch (err) {
      setError(err?.response?.data?.detail || 'Update failed')
    } finally {
      setSaving(false)
    }
  }

  return (
    <form onSubmit={onSubmit} className="bg-white border border-gray-200 rounded-xl p-6 space-y-5">
      {success && <div className="px-4 py-2.5 bg-green-50 border border-green-200 text-green-700 rounded-lg text-sm">{success}</div>}
      {error   && <div className="px-4 py-2.5 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">{error}</div>}

      <div>
        <label className="block text-xs font-semibold text-gray-500 mb-1">Full Name</label>
        <input
          required
          value={form.name}
          onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
      </div>
      <div>
        <label className="block text-xs font-semibold text-gray-500 mb-1">Email (read-only)</label>
        <input
          readOnly value={user.email}
          className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm bg-gray-50 text-gray-500 cursor-not-allowed"
        />
      </div>
      <div>
        <label className="block text-xs font-semibold text-gray-500 mb-1">Phone</label>
        <input
          value={form.phone}
          onChange={e => setForm(f => ({ ...f, phone: e.target.value }))}
          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          placeholder="+255 700 000 000"
        />
      </div>
      <div>
        <label className="block text-xs font-semibold text-gray-500 mb-1">Member Since</label>
        <input
          readOnly
          value={user.created_at ? new Date(user.created_at).toLocaleDateString('en-US', { dateStyle: 'long' }) : '—'}
          className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm bg-gray-50 text-gray-500 cursor-not-allowed"
        />
      </div>
      <button
        type="submit" disabled={saving}
        className="flex items-center gap-2 px-4 py-2 bg-brand-600 text-white rounded-lg text-sm font-medium hover:bg-brand-700 disabled:opacity-50"
      >
        <Save size={16} /> {saving ? 'Saving...' : 'Save Changes'}
      </button>
    </form>
  )
}

function ChangePasswordForm() {
  const [form, setForm]     = useState({ current: '', next: '', confirm: '' })
  const [saving, setSaving] = useState(false)
  const [error, setError]   = useState('')
  const [success, setSuccess] = useState('')

  const onSubmit = async (e) => {
    e.preventDefault()
    if (form.next !== form.confirm) { setError('New passwords do not match'); return }
    setSaving(true); setError(''); setSuccess('')
    try {
      await changePassword({ current_password: form.current, new_password: form.next })
      setSuccess('Password changed successfully.')
      setForm({ current: '', next: '', confirm: '' })
    } catch (err) {
      setError(err?.response?.data?.detail || 'Password change failed')
    } finally {
      setSaving(false)
    }
  }

  return (
    <form onSubmit={onSubmit} className="bg-white border border-gray-200 rounded-xl p-6 space-y-5">
      {success && <div className="px-4 py-2.5 bg-green-50 border border-green-200 text-green-700 rounded-lg text-sm">{success}</div>}
      {error   && <div className="px-4 py-2.5 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">{error}</div>}

      {[['current', 'Current Password'], ['next', 'New Password'], ['confirm', 'Confirm New Password']].map(([key, label]) => (
        <div key={key}>
          <label className="block text-xs font-semibold text-gray-500 mb-1">{label}</label>
          <input
            required type="password" minLength={key === 'current' ? 1 : 6}
            value={form[key]}
            onChange={e => setForm(f => ({ ...f, [key]: e.target.value }))}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>
      ))}
      <button
        type="submit" disabled={saving}
        className="flex items-center gap-2 px-4 py-2 bg-brand-600 text-white rounded-lg text-sm font-medium hover:bg-brand-700 disabled:opacity-50"
      >
        <Lock size={16} /> {saving ? 'Updating...' : 'Update Password'}
      </button>
    </form>
  )
}
