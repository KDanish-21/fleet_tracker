import { useAuth } from '../context/AuthContext'
import { useNavigate } from 'react-router-dom'
import { User, Mail, Phone, Calendar, LogOut, Shield } from 'lucide-react'

export default function Profile() {
  const { user, logout } = useAuth()
  const navigate = useNavigate()

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  if (!user) return null

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <h1 className="text-xl font-bold text-gray-900">Profile</h1>

      {/* Profile card */}
      <div className="card">
        <div className="flex items-center gap-5 mb-6 pb-6 border-b border-gray-100">
          <div className="w-20 h-20 rounded-2xl bg-brand-100 flex items-center justify-center">
            <User size={36} className="text-brand-600" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-gray-900">{user.name}</h2>
            <p className="text-sm text-gray-500">{user.email}</p>
            <span className="inline-flex items-center gap-1 mt-2 px-2 py-0.5 bg-green-50 text-green-700 text-xs rounded-full font-medium">
              <Shield size={10} /> Active Account
            </span>
          </div>
        </div>

        <div className="space-y-4">
          <InfoRow icon={<User size={16} />} label="Full Name" value={user.name} />
          <InfoRow icon={<Mail size={16} />} label="Email" value={user.email} />
          <InfoRow icon={<Phone size={16} />} label="Phone" value={user.phone || 'Not provided'} />
          <InfoRow icon={<Calendar size={16} />} label="Joined" value={user.created_at ? new Date(user.created_at).toLocaleDateString('en-US', { dateStyle: 'long' }) : '--'} />
        </div>
      </div>

      {/* Actions */}
      <div className="card">
        <h3 className="font-semibold text-gray-800 text-sm mb-4">Account Actions</h3>
        <button
          onClick={handleLogout}
          className="flex items-center gap-2 px-4 py-2.5 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition-colors text-sm font-medium"
        >
          <LogOut size={16} />
          Sign Out
        </button>
      </div>
    </div>
  )
}

function InfoRow({ icon, label, value }) {
  return (
    <div className="flex items-center gap-3 py-2">
      <span className="text-gray-400">{icon}</span>
      <div className="flex-1">
        <p className="text-xs text-gray-500">{label}</p>
        <p className="text-sm font-medium text-gray-800">{value}</p>
      </div>
    </div>
  )
}
