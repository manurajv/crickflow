/// Layout breakpoints for admin web — mobile-first responsive design.
abstract final class Breakpoints {
  /// Mobile phones (portrait and small landscape)
  static const double mobile = 0;
  
  /// Tablets and large phones (landscape)
  static const double tablet = 768;
  
  /// Laptops and small desktops
  static const double laptop = 1024;
  
  /// Standard desktops
  static const double desktop = 1440;
  
  /// Ultra-wide displays
  static const double wide = 1800;

  /// Sidebar width when expanded (desktop/laptop)
  static const double sidebarExpanded = 260;
  
  /// Sidebar width when collapsed (icon-only mode)
  static const double sidebarCollapsed = 72;
  
  /// Below this width, show drawer instead of persistent sidebar
  static const double drawerBreakpoint = tablet;
}
