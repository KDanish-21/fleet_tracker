import { useEffect, useState } from 'react'
import { Navigate, useSearchParams } from 'react-router-dom'
import { Trash2, Plus, RefreshCw, CheckCircle } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import {
  getTenantDevices,
  assignTenantDevice,
  removeTenantDevice,
} from '../api/client'

const ROLES_ALLOWED = new Set(['owner', 'admin'])

export default function TenantDevices() {
  const { user, loading: authLoading } = useAuth()
  const [devices, setDevices] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [form, setForm] = useState({ deviceId: '', deviceName: '' })
  const [submitting, setSubmitting] = useState(false)

  const [searchParams] = useSearchParams()
  const isOnboarding = searchParams.get('onboard') === '1'
  const role = user?.role
  const allowed = !!role && ROLES_ALLOWED.has(role)

  const load = async () => {
    setLoading(true)
    setError('')
    try {
      const res = await getTenantDevices()
      setDevices(res.data.devices || [])
    } catch (e) {
      setError(e?.response?.data?.detail || e.message || 'Failed to load devices')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (allowed) load()
  }, [allowed])

  if (authLoading) return null
  if (!allowed) return <Navigate to="/" replace />

  const onAssign = async (e) => {
    e.preventDefault()
    if (!form.deviceId.trim()) return
    setSubmitting(true)
    setError('')
    try {
      await assignTenantDevice(form.deviceId.trim(), form.deviceName.trim())
      setForm({ deviceId: '', deviceName: '' })
      await load()
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Assign failed')
    } finally {
      setSubmitting(false)
    }
  }

  const onRemove = async (deviceId) => {
    if (!window.confirm(`Unassign device ${deviceId} from this workspace?`)) return
    setError('')
    try {
      await removeTenantDevice(deviceId)
      await load()
    } catch (err) {
      setError(err?.response?.data?.detail || err.message || 'Remove failed')
    }
  }

  return (
    <div className="max-w-5xl mx-auto">
      {isOnboarding && (
        <div className="mb-6 px-5 py-4 bg-green-50 border border-green-200 rounded-xl flex items-start gap-3">
          <CheckCircle size={20} className="text-green-600 mt-0.5 flex-shrink-0" />
          <div>
            <p className="font-semibold text-green-800">Workspace created! Welcome aboard.</p>
            <p className="text-sm text-green-700 mt-0.5">
              Assign your GPS51 device IDs below to start tracking. You can find device IDs (IMEI) on the GPS51 platform or on the device label.
            </p>
          </div>
        </div>
      )}
      <div className="flex items-center justify-between mb-5">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Tenant Devices</h1>
          <p className="text-sm text-gray-500 mt-1">
            GPS devices linked to this workspace. Only assigned devices are visible to tenant users.
          </p>
        </div>
        <button
          onClick={load}
          className="flex items-center gap-2 px-3 py-2 text-sm bg-white border border-gray-200 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      <form
        onSubmit={onAssign}
        className="bg-white border border-gray-200 rounded-xl p-5 mb-6 grid grid-cols-1 md:grid-cols-[1fr_1fr_auto] gap-3"
      >
        <div>
          <label className="block text-xs font-semibold text-gray-500 mb-1">
            Device ID (GPS51 IMEI)
          </label>
          <input
            type="text"
            required
            value={form.deviceId}
            onChange={(e) => setForm((f) => ({ ...f, deviceId: e.target.value }))}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            placeholder="e.g. 862205051234567"
          />
        </div>
        <div>
          <label className="block text-xs font-semibold text-gray-500 mb-1">
            Device Name (optional)
          </label>
          <input
            type="text"
            value={form.deviceName}
            onChange={(e) => setForm((f) => ({ ...f, deviceName: e.target.value }))}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            placeholder="e.g. Truck 01"
          />
        </div>
        <div className="flex items-end">
          <button
            type="submit"
            disabled={submitting}
            className="flex items-center gap-2 px-4 py-2 bg-brand-600 text-white rounded-lg text-sm font-medium hover:bg-brand-700 disabled:opacity-50"
          >
            <Plus size={16} />
            {submitting ? 'Assigning...' : 'Assign Device'}
          </button>
        </div>
      </form>

      {error && (
        <div className="mb-4 px-4 py-2.5 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="bg-white border border-gray-200 rounded-xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-600">
            <tr>
              <th className="text-left px-4 py-3 font-semibold">Device ID</th>
              <th className="text-left px-4 py-3 font-semibold">Name</th>
              <th className="text-left px-4 py-3 font-semibold">Assigned</th>
              <th className="px-4 py-3 w-24"></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan="4" className="px-4 py-8 text-center text-gray-400">
                  Loading devices...
                </td>
              </tr>
            ) : devices.length === 0 ? (
              <tr>
                <td colSpan="4" className="px-4 py-8 text-center text-gray-400">
                  No devices assigned yet. Assign one above to start tracking.
                </td>
              </tr>
            ) : (
              devices.map((d) => (
                <tr key={d.device_id} className="border-t border-gray-100">
                  <td className="px-4 py-3 font-mono text-gray-800">{d.device_id}</td>
                  <td className="px-4 py-3 text-gray-700">{d.device_name || '—'}</td>
                  <td className="px-4 py-3 text-gray-500">
                    {d.created_at ? new Date(d.created_at).toLocaleString() : '—'}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => onRemove(d.device_id)}
                      className="inline-flex items-center gap-1 text-red-600 hover:text-red-700 text-xs font-medium"
                    >
                      <Trash2 size={14} /> Remove
                    </button>
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
