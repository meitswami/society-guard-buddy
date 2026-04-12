import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import SuperadminLoginForm from '@/components/SuperadminLoginForm';
import { LoginFooter } from '@/components/LoginFooter';

interface Props {
  onLogin: (sa: { id: string; name: string; username: string }) => void;
  onBack?: () => void;
}

const SuperadminLoginPage = ({ onLogin, onBack }: Props) => {
  return (
    <div className="relative flex min-h-screen flex-col items-center justify-center bg-background px-6 pb-36">
      <div className="absolute top-4 right-4 flex items-center gap-2">
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <SuperadminLoginForm onLogin={onLogin} onBack={onBack} variant="full" />
      <LoginFooter />
    </div>
  );
};

export default SuperadminLoginPage;
