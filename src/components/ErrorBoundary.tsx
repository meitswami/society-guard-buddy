import { Component, type ErrorInfo, type ReactNode } from 'react';

type Props = {
  children: ReactNode;
  title?: string;
  onReset?: () => void;
};

type State = {
  error: Error | null;
};

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('[ErrorBoundary]', error, info.componentStack);
  }

  private reset = () => {
    this.setState({ error: null });
    this.props.onReset?.();
  };

  render() {
    if (this.state.error) {
      return (
        <div className="page-container pb-24">
          <div className="card-section p-4 border border-destructive/40 bg-destructive/5 space-y-3">
            <p className="text-sm font-semibold text-destructive">{this.props.title ?? 'Something went wrong'}</p>
            <p className="text-xs text-muted-foreground leading-snug">
              This screen hit an unexpected error and could not finish loading. You can try again or go back to the admin
              home screen.
            </p>
            <p className="text-[10px] font-mono text-muted-foreground break-all">{this.state.error.message}</p>
            <button type="button" className="btn-primary w-full" onClick={this.reset}>
              Try again
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
