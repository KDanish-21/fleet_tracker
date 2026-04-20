import { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { Save, AlertTriangle } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { getTenantSettings, updateTenantSettings, deactivateTenant } from '../api/client'

const CURRENCIES = ['USD', 'TZS', 'KES', 'UGX', 'EUR', 'GBP', 'INR', 'ZAR']

export default function TenantSettings() {
  const { user, loading: authLoading } = useAuth()
  const isOwner = user?.role === 'owner'

  const [tenant, setTenant]   = useState(null)
  const [form, setForm]       = useState({ name: '', currency: 'USD' })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving]   = useState(false)
  const [error, setError]     = useState('')
  const [success, setSuccess] = useState('')
  const [confirmDeactivate, setConfirmDeactivate] = useState(false)

  useEffect(() => {
    if (!isOwner && !authLoading) return
    getTenantSettings()
      .then(res => {
        setTenant(res.data)
        setForm({ name: res.data.name || '', currency: res.data.currency || 'USD' })
      })
      .catch(e => setError(e?.response?.data?.detail || 'Failed to load settings'))
      .finally(() => setLoading(false))
  }, [isOwner, authLoading])

  if (authLoading) return null
  if (!isOwner) return <Navigate to="/" replace />

  const onSave = async (e) => {
    e.preventDefault()
    setSaving(true)
    setError('')
    setSuccess('')
    try {
      const res = await updateTenantSettings({ name: form.name, currency: form.currency })
      setTenant(res.data)
      setSuccess('Workspace settings saved.')
    } catch (err) {
      setError(err?.response?.data?.detail || 'Save failed')
    } finally {
      setSaving(false)
    }
  }

  const onDeactivate = async () => {
    try {
      await deactivateTenant()
      localStorage.removeItem('token')
      localStorage.removeItem('user')
      window.location.href = '/login'
    } catch (err) {
      setError(err?.response?.data?.detail || 'Deactivation failed')
      setConfirmDeactivate(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Workspace Settings</h1>
        <p className="text-sm text-gray-500 mt-1">Manage your workspace name, currency and lifecycle.</p>
      </div>

      {loading ? (
        <div className="text-gray-400 text-sm">Loading...</div>
      ) : (
        <>
          <form onSubmit={onSave} className="bg-white border border-gray-200 rounded-xl p-6 space-y-5">
            <h2 className="font-semibold text-gray-800">General</h2>

            {success && (
              <div className="px-4 py-2.5 bg-green-50 border border-green-200 text-green-700 rounded-lg text-sm">
                {success}
              </div>
            )}
            {error && (
              <div className="px-4 py-2.5 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
                {error}
              </div>
            )}

            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Workspace Slug (read-only)</label>
              <input
                readOnly
                value={tenant?.slug || ''}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm bg-gray-50 text-gray-500 cursor-not-allowed"
              />
              <p className="text-xs text-gray-400 mt-1">Slug cannot be changed after creation.</p>
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Workspace Name</label>
              <input
                required
                value={form.name}
                onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                placeholder="My Company"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Currency</label>
              <select
                value={form.currency}
                onChange={e => setForm(f => ({ ...f, currency: e.target.value }))}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-brand-500"
              >
                {CURRENCIES.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>

            <button
              type="submit"
              disabled={saving}
              className="flex items-center gap-2 px-4 py-2 bg-brand-600 text-white rounded-lg text-sm font-medium hover:bg-brand-700 disabled:opacity-50"
            >
              <Save size={16} /> {saving ? 'Saving...' : 'Save Changes'}
            </button>
          </form>

          {/* Danger zone */}
          <div className="bg-white border border-red-200 rounded-xl p-6 space-y-4">
            <h2 className="font-semibold text-red-700 flex items-center gap-2">
              <AlertTriangle size={16} /> Danger Zone
            </h2>
            <p className="text-sm text-gray-600">
              Deactivating your workspace will immediately block all logins for every user in this workspace.
              This cannot be undone from the app.
            </p>
            {!confirmDeactivate ? (
              <button
                onClick={() => setConfirmDeactivate(true)}
                className="px-4 py-2 text-sm font-medium text-red-600 border border-red-300 rounded-lg hover:bg-red-50"
              >
                Deactivate Workspace
              </button>
            ) : (
              <div className="flex items-center gap-3">
                <button
                  onClick={onDeactivate}
                  className="px-4 py-2 text-sm font-medium bg-red-600 text-white rounded-lg hover:bg-red-700"
                >
                  Yes, deactivate permanently
                </button>
                <button
                  onClick={() => setConfirmDeactivate(false)}
                  className="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
                >
                  Cancel
                </button>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  )
}
