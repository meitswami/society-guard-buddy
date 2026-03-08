import { useState } from 'react';
import { useStore } from '@/store/useStore';
import { Shield, Eye, EyeOff } from 'lucide-react';

const LoginPage = () => {
  const [guardId, setGuardId] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const login = useStore(s => s.login);

  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!guardId || !password) {
      setError('Enter Guard ID and Password');
      return;
    }
    setLoading(true);
    const success = await login(guardId.toUpperCase(), password);
    setLoading(false);
    if (!success) setError('Invalid credentials');
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-background">
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-10">
          <div className="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
            <Shield className="w-10 h-10 text-primary" />
          </div>
          <h1 className="page-title text-2xl">Gate Security</h1>
          <p className="text-muted-foreground text-sm mt-1">Society Management System</p>
        </div>

        <form onSubmit={handleLogin} className="flex flex-col gap-4">
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Guard ID</label>
            <input
              className="input-field font-mono uppercase"
              placeholder="e.g. G001"
              value={guardId}
              onChange={e => setGuardId(e.target.value)}
            />
          </div>

          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Password</label>
            <div className="relative">
              <input
                className="input-field pr-10"
                type={showPassword ? 'text' : 'password'}
                placeholder="Enter password"
                value={password}
                onChange={e => setPassword(e.target.value)}
              />
              <button
                type="button"
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                onClick={() => setShowPassword(!showPassword)}
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          {error && (
            <p className="text-destructive text-sm text-center">{error}</p>
          )}

          <button type="submit" className="btn-primary mt-2">
            Start Shift
          </button>

          <p className="text-xs text-muted-foreground text-center mt-4">
            Demo: G001 / guard123
          </p>
        </form>
      </div>
    </div>
  );
};

export default LoginPage;
