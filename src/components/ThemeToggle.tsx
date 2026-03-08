import { Moon, Sun, Monitor } from 'lucide-react';
import { useStore } from '@/store/useStore';

const ThemeToggle = () => {
  const { theme, setTheme } = useStore();

  const options = [
    { value: 'light' as const, icon: Sun },
    { value: 'system' as const, icon: Monitor },
    { value: 'dark' as const, icon: Moon },
  ];

  return (
    <div className="flex bg-secondary rounded-lg p-0.5 gap-0.5">
      {options.map(({ value, icon: Icon }) => (
        <button
          key={value}
          onClick={() => setTheme(value)}
          className={`p-1.5 rounded-md transition-colors ${theme === value ? 'bg-primary text-primary-foreground' : 'text-muted-foreground'}`}
          aria-label={`${value} theme`}
        >
          <Icon className="w-3.5 h-3.5" />
        </button>
      ))}
    </div>
  );
};

export default ThemeToggle;
