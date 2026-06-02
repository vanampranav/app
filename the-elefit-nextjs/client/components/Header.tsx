import { Link } from 'react-router-dom';

export function Header() {
  return (
    <header className="fixed top-0 left-0 right-0 z-50 w-full border-b border-[#212121] bg-[#0D0D0D] backdrop-blur md:sticky">
      <div className="container flex h-[68px] w-full items-center justify-between px-[119px] max-w-full">
        {/* Logo */}
        <Link to="/" className="flex items-center">
          <div className="text-2xl font-bold">
            <span className="text-primary">ELEFIT</span>
            <span className="text-xs text-muted-foreground ml-1">GEAR UP!</span>
          </div>
        </Link>

        {/* Navigation */}
        <nav className="flex items-center gap-6">
          <Link 
            to="/" 
            className="px-4 py-2 text-sm font-medium text-white hover:text-primary transition-colors"
          >
            Home
          </Link>
          <Link 
            to="/community" 
            className="px-4 py-2 text-sm font-medium text-white hover:text-primary transition-colors"
          >
            Community
          </Link>
          <Link 
            to="/find-expert" 
            className="px-4 py-2 text-sm font-medium text-white hover:text-primary transition-colors"
          >
            Find Expert
          </Link>
          <Link 
            to="/apply-expert" 
            className="px-4 py-2 text-sm font-medium text-white hover:text-primary transition-colors"
          >
            Apply as Expert
          </Link>
          <Link 
            to="/ai-coach" 
            className="px-4 py-2 rounded bg-primary text-black text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            AI Coach
          </Link>
        </nav>
      </div>
    </header>
  );
}
