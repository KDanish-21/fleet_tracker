import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { getTenantSlug } from '../api/client'
import { Truck, Mail, Lock, Eye, EyeOff, MapPin, Shield, Activity } from 'lucide-react'

export default function Login() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [form, setForm] = useState({ tenantSlug: getTenantSlug(), email: '', password: '' })
  const [showPw, setShowPw] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await login(form.email, form.password, form.tenantSlug)
      navigate('/')
    } catch (err) {
      setError(err.response?.data?.detail || 'Login failed. Please check your credentials.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex">
      {/* Left side - branding */}
      <div className="hidden lg:flex lg:w-1/2 relative overflow-hidden">
        {/* Truck highway image */}
        <img
          src="/truck-highway.jpg"
          alt="Fleet trucks on highway"
          className="absolute inset-0 w-full h-full object-cover"
        />
        {/* Dark overlay */}
        <div className="absolute inset-0 bg-gradient-to-b from-brand-900/85 via-brand-900/75 to-brand-900/90" />

        {/* Animated GPS dots */}
        <div className="absolute top-1/4 left-1/4 w-3 h-3 bg-green-400 rounded-full animate-pulse shadow-lg shadow-green-400/50" />
        <div className="absolute top-1/3 right-1/3 w-3 h-3 bg-green-400 rounded-full animate-pulse shadow-lg shadow-green-400/50" style={{ animationDelay: '0.3s' }} />
        <div className="absolute bottom-1/3 left-1/3 w-3 h-3 bg-yellow-400 rounded-full animate-pulse shadow-lg shadow-yellow-400/50" style={{ animationDelay: '0.7s' }} />
        <div className="absolute top-2/3 right-1/4 w-3 h-3 bg-green-400 rounded-full animate-pulse shadow-lg shadow-green-400/50" style={{ animationDelay: '0.5s' }} />
        <div className="absolute bottom-1/4 left-1/2 w-2.5 h-2.5 bg-red-400 rounded-full animate-pulse shadow-lg shadow-red-400/50" style={{ animationDelay: '0.2s' }} />

        {/* Route lines */}
        <svg className="absolute inset-0 w-full h-full opacity-30" xmlns="http://www.w3.org/2000/svg">
          <path d="M 100 200 Q 300 100 500 300 T 900 400" stroke="#22c55e" strokeWidth="2" fill="none" strokeDasharray="6 4" />
          <path d="M 50 500 Q 200 300 400 450 T 800 200" stroke="#3b82f6" strokeWidth="2" fill="none" strokeDasharray="6 4" />
        </svg>

        {/* Content */}
        <div className="relative z-10 flex flex-col justify-center px-16">
          <div className="flex items-center gap-4 mb-10">
            <div className="w-16 h-16 bg-white/15 backdrop-blur-md rounded-2xl flex items-center justify-center border border-white/20">
              <Truck size={36} className="text-white" />
            </div>
            <div>
              <h1 className="text-5xl font-extrabold text-white tracking-tight">FleetTracker</h1>
              <p className="text-white/50 text-sm mt-1">GPS Fleet Management System</p>
            </div>
          </div>

          <h2 className="text-4xl font-bold text-white leading-tight mb-4">
            Track your fleet<br />
            <span className="text-green-400">in real-time</span>
          </h2>
          <p className="text-white/50 text-lg max-w-md mb-12">
            Monitor vehicle locations, speed, fuel consumption, and alerts from a single powerful dashboard.
          </p>

          <div className="space-y-5">
            <Feature icon={<MapPin size={18} />} title="Live GPS Tracking" desc="Real-time vehicle positions updated every 10 seconds" />
            <Feature icon={<Activity size={18} />} title="Fleet Analytics" desc="Speed, fuel, mileage, and trip history reports" />
            <Feature icon={<Shield size={18} />} title="Instant Alerts" desc="Overspeed, geofence, SOS, and fuel theft notifications" />
          </div>
        </div>
      </div>

      {/* Right side - form */}
      <div className="flex-1 flex items-center justify-center p-6 bg-gray-50 lg:p-12">
        <div className="w-full max-w-md">
          {/* Mobile logo */}
          <div className="lg:hidden text-center mb-8">
            <div className="inline-flex items-center gap-3 mb-2">
              <div className="w-12 h-12 bg-brand-600 rounded-xl flex items-center justify-center">
                <Truck size={24} className="text-white" />
              </div>
              <h1 className="text-3xl font-extrabold text-gray-900">FleetTracker</h1>
            </div>
            <p className="text-gray-500 text-sm">GPS Fleet Management System</p>
          </div>

          {/* Card */}
          <div className="bg-white rounded-2xl shadow-xl border border-gray-100 p-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-1">Welcome back</h2>
            <p className="text-sm text-gray-500 mb-8">Sign in to your account to continue</p>

            {error && (
              <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg text-sm mb-5 font-medium border border-red-100">
                {error}
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-5">
              <InputField
                label="Workspace"
                icon={<Shield size={18} />}
                type="text"
                required
                placeholder="company-slug"
                value={form.tenantSlug}
                onChange={v => setForm(s => ({ ...s, tenantSlug: v }))}
              />
              <InputField
                label="Email"
                icon={<Mail size={18} />}
                type="email"
                required
                placeholder="you@example.com"
                value={form.email}
                onChange={v => setForm(s => ({ ...s, email: v }))}
              />
              <InputField
                label="Password"
                icon={<Lock size={18} />}
                type={showPw ? 'text' : 'password'}
                required
                placeholder="Enter your password"
                value={form.password}
                onChange={v => setForm(s => ({ ...s, password: v }))}
                right={
                  <button type="button" onClick={() => setShowPw(s => !s)} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                    {showPw ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                }
              />

              <button type="submit" disabled={loading} className="btn-primary w-full py-3 text-base font-semibold">
                {loading ? 'Signing in...' : 'Sign In'}
              </button>
            </form>

            <p className="text-center text-sm text-gray-500 mt-8">
              Don't have an account?{' '}
              <Link to="/register" className="text-brand-600 font-semibold hover:text-brand-700">Create account</Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}

function InputField({ label, icon, type, required, placeholder, value, onChange, right }) {
  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1.5">{label}</label>
      <div className="relative">
        <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none">{icon}</span>
        <input
          type={type}
          required={required}
          placeholder={placeholder}
          value={value}
          onChange={e => onChange(e.target.value)}
          style={{ paddingLeft: '2.75rem', paddingRight: right ? '2.75rem' : '0.75rem' }}
          className="w-full border border-gray-200 rounded-lg py-2.5 text-sm outline-none focus:border-brand-500 bg-white"
        />
        {right}
      </div>
    </div>
  )
}

function Feature({ icon, title, desc }) {
  return (
    <div className="flex items-start gap-3">
      <div className="w-10 h-10 rounded-lg bg-white/10 backdrop-blur-sm flex items-center justify-center flex-shrink-0 text-green-400 border border-white/10">
        {icon}
      </div>
      <div>
        <p className="text-white font-semibold text-sm">{title}</p>
        <p className="text-white/40 text-xs">{desc}</p>
      </div>
    </div>
  )
}
