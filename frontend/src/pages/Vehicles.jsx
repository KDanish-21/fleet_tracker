import { useState } from 'react'
import { useFleet } from '../context/FleetContext'
import { addVehicle } from '../api/client'
import { Plus, Truck, CheckCircle, XCircle, Wifi, WifiOff } from 'lucide-react'

export default function Vehicles() {
  const { vehicles, loading, refresh } = useFleet()
  const [showForm, setShowForm]         = useState(false)
  const [form, setForm]                 = useState({ deviceid: '', devicename: '', devicetype: 0 })
  const [submitting, setSubmitting]     = useState(false)
  const [result, setResult]             = useState(null)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSubmitting(true)
    setResult(null)
    try {
      await addVehicle(form)
      setResult({ ok: true, msg: 'Vehicle registered successfully' })
      setForm({ deviceid: '', devicename: '', devicetype: 0 })
      setShowForm(false)
      await refresh()
    } catch (err) {
      setResult({ ok: false, msg: err.response?.data?.detail || 'Registration failed' })
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-900">Vehicles</h1>
          <p className="text-sm text-gray-500">{vehicles.length} registered devices</p>
        </div>
        <button className="btn-primary flex items-center gap-2" onClick={() => setShowForm(s => !s)}>
          <Plus size={16} />
          Register Vehicle
        </button>
      </div>

      {/* Result message */}
      {result && (
        <div className={`flex items-center gap-2 px-4 py-3 rounded-lg text-sm font-medium ${
          result.ok ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'
        }`}>
          {result.ok ? <CheckCircle size={16} /> : <XCircle size={16} />}
          {result.msg}
        </div>
      )}

      {/* Register form */}
      {showForm && (
        <div className="card">
          <h2 className="font-semibold text-gray-800 mb-4">Register New Vehicle</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-3 gap-4">
            <Field label="Device ID / IMEI" required>
              <input
                type="text"
                required
                placeholder="e.g. 864123456789012"
                value={form.deviceid}
                onChange={e => setForm(s => ({ ...s, deviceid: e.target.value }))}
                className="input"
              />
            </Field>
            <Field label="Vehicle Name" required>
              <input
                type="text"
                required
                placeholder="e.g. Truck TZ-001"
                value={form.devicename}
                onChange={e => setForm(s => ({ ...s, devicename: e.target.value }))}
                className="input"
              />
            </Field>
            <Field label="Device Type">
              <input
                type="number"
                value={form.devicetype}
                onChange={e => setForm(s => ({ ...s, devicetype: parseInt(e.target.value) }))}
                className="input"
              />
            </Field>
            <div className="col-span-3 flex gap-3">
              <button type="submit" disabled={submitting} className="btn-primary">
                {submitting ? 'Registering...' : 'Register'}
              </button>
              <button type="button" className="btn-secondary" onClick={() => setShowForm(false)}>
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Vehicle table */}
      <div className="card p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 border-b border-gray-100">
              <Th>Vehicle</Th>
              <Th>Device ID</Th>
              <Th>SIM</Th>
              <Th>Status</Th>
              <Th>Speed</Th>
              <Th>Fuel</Th>
              <Th>Mileage</Th>
              <Th>Connection</Th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={8} className="text-center py-8 text-gray-400">Loading...</td></tr>
            ) : vehicles.length === 0 ? (
              <tr><td colSpan={8} className="text-center py-8 text-gray-400">No vehicles registered</td></tr>
            ) : (
              vehicles.map((v, i) => {
                const pos = v.position
                return (
                  <tr key={v.deviceid} className={`border-b border-gray-50 hover:bg-gray-50 ${i % 2 === 0 ? '' : 'bg-gray-50/30'}`}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <Truck size={15} className="text-brand-500" />
                        <span className="font-medium text-gray-900">{v.devicename || '--'}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-gray-500 font-mono text-xs">{v.deviceid}</td>
                    <td className="px-4 py-3 text-gray-500">{v.Phone || v.simnum || '--'}</td>
                    <td className="px-4 py-3">
                      {!pos ? <span className="badge-stopped">Offline</span>
                        : pos.moving ? <span className="badge-moving">Moving</span>
                        : <span className="badge-idle">Stopped</span>}
                    </td>
                    <td className="px-4 py-3 text-gray-700">{pos ? `${Math.round(pos.speed || 0)} km/h` : '--'}</td>
                    <td className="px-4 py-3 text-gray-700">{pos ? `${pos.fuel_l ?? '--'} L` : '--'}</td>
                    <td className="px-4 py-3 text-gray-700">{pos ? `${pos.total_distance_km} km` : '--'}</td>
                    <td className="px-4 py-3">
                      {pos?.online ? (
                        <span className="flex items-center gap-1 text-green-600 text-xs font-medium">
                          <Wifi size={12} /> Online
                        </span>
                      ) : (
                        <span className="flex items-center gap-1 text-red-400 text-xs font-medium">
                          <WifiOff size={12} /> Offline
                        </span>
                      )}
                    </td>
                  </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function Th({ children }) {
  return <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{children}</th>
}

function Field({ label, children, required }) {
  return (
    <div>
      <label className="block text-xs font-medium text-gray-600 mb-1">
        {label}{required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      {children}
    </div>
  )
}
