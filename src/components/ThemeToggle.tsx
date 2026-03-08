import { Moon, Sun } from 'lucide-react';
import { useStore } from '@/store/useStore';

const ThemeToggle = () => {
  const { theme, toggleTheme } = useStore();

  return (
    <button
      onClick={toggleTheme}
      className="p-2 rounded-lg bg-secondary text-secondary-foreground transition-colors"
      aria-label="Toggle theme"
    >
      {theme === 'dark' ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
    </button>
  );
};

export default ThemeToggle;
