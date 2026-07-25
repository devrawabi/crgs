import { useState } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { Eye, EyeOff, Hash, Lock } from 'lucide-react'
import logo from '../assets/crgs-logo.png'
import { useAuth } from '../context/AuthContext'
import { FormField, inputClass } from '../components/ui/PageHeader'
import { Button } from '../components/ui/Button'

export function LoginPage() {
  const { login, isAuthenticated, isLoading } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const from = (location.state as { from?: { pathname: string } })?.from?.pathname ?? '/'

  const [employeeCode, setEmployeeCode] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [submitting, setSubmitting] = useState(false)

  if (!isLoading && isAuthenticated) {
    return <Navigate to={from} replace />
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSubmitting(true)

    const result = await login(employeeCode, password)
    setSubmitting(false)

    if (result.success) {
      navigate(from, { replace: true })
    } else {
      setError(result.error ?? 'Login failed')
    }
  }

  return (
    <div className="min-h-screen flex">
      <div className="hidden lg:flex lg:w-1/2 bg-sidebar text-white flex-col justify-between p-12">
        <div className="flex items-center gap-3">
          <img src={logo} alt="CRGS Admin" className="w-12 h-12 rounded-xl object-cover" />
          <div>
            <p className="font-bold text-lg">CRGS Admin</p>
            <p className="text-sm text-gray-400">Sales Manager Portal</p>
          </div>
        </div>

        <div>
          <h1 className="text-3xl font-bold leading-tight mb-4">
            Customer Recovery &amp; Growth System
          </h1>
          <p className="text-gray-400 text-lg leading-relaxed max-w-md">
            Manage routes, targets, tasks, and field performance from one admin dashboard.
          </p>
        </div>

        <p className="text-xs text-gray-500">&copy; {new Date().getFullYear()} CRGS. All rights reserved.</p>
      </div>

      <div className="flex-1 flex items-center justify-center p-6 bg-gray-50">
        <div className="w-full max-w-md">
          <div className="lg:hidden flex items-center gap-3 mb-8">
            <img src={logo} alt="CRGS Admin" className="w-10 h-10 rounded-lg object-cover" />
            <div>
              <p className="font-bold text-gray-900">CRGS Admin</p>
              <p className="text-xs text-gray-500">Sales Manager Portal</p>
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-8">
            <div className="mb-8">
              <h2 className="text-2xl font-bold text-gray-900">Sign in</h2>
              <p className="text-sm text-gray-500 mt-1">
                Enter your credentials to access the admin portal
              </p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-5">
              {error && (
                <div className="px-4 py-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700">
                  {error}
                </div>
              )}

              <FormField label="Employee Code" required>
                <div className="relative">
                  <Hash
                    size={16}
                    className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
                  />
                  <input
                    type="text"
                    className={inputClass + ' pl-9'}
                    value={employeeCode}
                    onChange={(e) => setEmployeeCode(e.target.value)}
                    placeholder="Enter employee code"
                    autoComplete="username"
                    required
                  />
                </div>
              </FormField>

              <FormField label="Password" required>
                <div className="relative">
                  <Lock
                    size={16}
                    className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
                  />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    className={inputClass + ' pl-9 pr-10'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Enter your password"
                    autoComplete="current-password"
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    tabIndex={-1}
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </FormField>

              <Button type="submit" className="w-full" disabled={submitting}>
                {submitting ? 'Signing in...' : 'Sign in'}
              </Button>
            </form>
          </div>
        </div>
      </div>
    </div>
  )
}
