import MenuIcon from '@mui/icons-material/Menu';
import NotificationsNoneIcon from '@mui/icons-material/NotificationsNone';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import {
  AppBar,
  Avatar,
  Badge,
  Box,
  Divider,
  Drawer,
  IconButton,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Menu,
  MenuItem,
  Stack,
  Toolbar,
  Tooltip,
  Typography,
  useMediaQuery,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useState } from 'react';
import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import DashboardIcon from '@mui/icons-material/SpaceDashboard';
import ApartmentIcon from '@mui/icons-material/Apartment';
import PeopleIcon from '@mui/icons-material/People';
import AssessmentIcon from '@mui/icons-material/Assessment';
import EventNoteIcon from '@mui/icons-material/EventNote';
import CampaignIcon from '@mui/icons-material/Campaign';
import LogoutIcon from '@mui/icons-material/Logout';
import { useAuth } from '../context/AuthContext';
import { APP_CONTENT_MAX_WIDTH_PX } from '../constants/layout';
import { NotificationPopover } from '../components/layout/NotificationPopover';
import { getRoleLabel } from '../utils/roleLabels';
import * as notificationService from '../services/notificationService';

const drawerWidth = 280;
const LOGO_SRC = '/logo.png';

/** Khớp chiều cao Toolbar — Drawer bắt đầu ngay dưới AppBar, không cắt nội dung */
const toolbarOffset = { xs: '56px', sm: '64px' };

function headerAvatar(name: string) {
  const colors = ['#ec407a', '#ab47bc', '#5c6bc0', '#26a69a', '#ffa726', '#78909c'];
  let h = 0;
  for (let i = 0; i < name.length; i++) h = name.charCodeAt(i) + ((h << 5) - h);
  const bg = colors[Math.abs(h) % colors.length];
  return {
    sx: {
      width: 36,
      height: 36,
      fontSize: '0.95rem',
      fontWeight: 700,
      bgcolor: bg,
      color: '#fff',
      border: '2px solid rgba(255,255,255,0.35)',
    },
    children: (name || '?').charAt(0).toUpperCase(),
  };
}

export function MainLayout() {
  const theme = useTheme();
  const mobile = useMediaQuery(theme.breakpoints.down('md'));
  const [open, setOpen] = useState(!mobile);
  const { user, logout } = useAuth();
  const nav = useNavigate();
  const loc = useLocation();
  const [unread, setUnread] = useState<number | null>(null);
  const [userMenuAnchor, setUserMenuAnchor] = useState<null | HTMLElement>(null);
  const [notifAnchor, setNotifAnchor] = useState<null | HTMLElement>(null);

  const refreshUnread = useCallback(async () => {
    try {
      const c = await notificationService.fetchUnreadCount();
      setUnread(c);
    } catch {
      setUnread(null);
    }
  }, []);

  useEffect(() => {
    refreshUnread();
  }, [loc.pathname, refreshUnread]);

  useEffect(() => {
    setOpen(!mobile);
  }, [mobile]);

  const allStaffRoles = ['ADMIN', 'EMPLOYEE', 'HR', 'HEAD_DEPARTMENT', 'HEAD_NURSING'] as const;

  const items = [
    { to: '/', label: 'Dashboard', icon: <DashboardIcon />, roles: allStaffRoles },
    { to: '/announcements', label: 'Thông báo toàn viện', icon: <CampaignIcon />, roles: allStaffRoles },
    { to: '/departments', label: 'Phòng ban', icon: <ApartmentIcon />, roles: ['ADMIN'] as const },
    { to: '/employees', label: 'Nhân viên', icon: <PeopleIcon />, roles: ['ADMIN'] as const },
    {
      to: '/evaluations',
      label: 'Đánh giá & xếp loại',
      icon: <AssessmentIcon />,
      roles: allStaffRoles,
    },
    { to: '/work', label: 'Công & Lương', icon: <EventNoteIcon />, roles: allStaffRoles },
  ];

  const filtered = items.filter((i) => user && (i.roles as readonly string[]).includes(user.role));

  function navActive(path: string): boolean {
    if (path === '/') {
      return loc.pathname === '/';
    }
    return loc.pathname === path || loc.pathname.startsWith(`${path}/`);
  }

  const drawer = (
    <Box
      sx={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: `linear-gradient(180deg, ${alpha(theme.palette.primary.main, 0.04)} 0%, ${theme.palette.background.paper} 28%)`,
      }}
    >
      <Box
        sx={{
          px: 2,
          py: 2,
          borderBottom: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
        }}
      >
        <Stack direction="row" alignItems="center" spacing={1.5}>
          <Box
            component="img"
            src={LOGO_SRC}
            alt=""
            sx={{
              width: 44,
              height: 44,
              borderRadius: '50%',
              bgcolor: 'rgba(255,255,255,0.95)',
              p: 0.35,
              objectFit: 'contain',
              boxShadow: `0 2px 10px ${alpha('#000', 0.12)}`,
            }}
          />
          <Box sx={{ minWidth: 0 }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, letterSpacing: '-0.02em', lineHeight: 1.25 }}>
              Minh An HRM
            </Typography>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
              Quản trị nhân sự
            </Typography>
          </Box>
        </Stack>
      </Box>
      <List sx={{ flex: 1, py: 2, pt: { xs: 2, md: 1.5 }, px: 0.5, minHeight: 0, overflowY: 'auto' }}>
        {filtered.map((item) => {
          const active = navActive(item.to);
          return (
            <ListItemButton
              key={item.to}
              component={Link}
              to={item.to}
              selected={active}
              onClick={() => mobile && setOpen(false)}
              sx={{
                transition: 'background-color 0.15s ease',
                '&.Mui-selected .MuiListItemIcon-root': {
                  color: 'primary.main',
                },
              }}
            >
              <ListItemIcon
                sx={{
                  minWidth: 42,
                  color: active ? 'primary.main' : 'text.secondary',
                }}
              >
                {item.icon}
              </ListItemIcon>
              <ListItemText
                primary={item.label}
                primaryTypographyProps={{
                  fontWeight: active ? 600 : 500,
                  fontSize: '0.875rem',
                  letterSpacing: '-0.01em',
                }}
              />
            </ListItemButton>
          );
        })}
      </List>
      <Divider sx={{ borderColor: alpha(theme.palette.primary.main, 0.12) }} />
      <List sx={{ py: 1, px: 0.5 }}>
        <ListItemButton
          onClick={() => {
            logout();
            nav('/login');
          }}
          sx={{ color: 'text.secondary' }}
        >
          <ListItemIcon sx={{ minWidth: 42, color: 'inherit' }}>
            <LogoutIcon />
          </ListItemIcon>
          <ListItemText
            primary="Đăng xuất"
            primaryTypographyProps={{ fontWeight: 500, fontSize: '0.875rem', letterSpacing: '-0.01em' }}
          />
        </ListItemButton>
      </List>
    </Box>
  );

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      <AppBar
        position="fixed"
        color="primary"
        elevation={0}
        sx={{
          zIndex: (t) => t.zIndex.appBar,
          borderBottom: `1px solid ${alpha('#000', 0.06)}`,
        }}
      >
        <Toolbar sx={{ minHeight: { xs: 56, sm: 64 } }}>
          <IconButton
            edge="start"
            onClick={() => setOpen((o) => !o)}
            sx={{
              mr: 1.5,
              color: 'inherit',
              display: { md: 'none' },
            }}
            aria-label="Mở menu"
          >
            <MenuIcon />
          </IconButton>
          <Box
            component="img"
            src={LOGO_SRC}
            alt=""
            sx={{
              width: 40,
              height: 40,
              mr: 1.5,
              borderRadius: '50%',
              bgcolor: 'rgba(255,255,255,0.95)',
              p: 0.35,
              objectFit: 'contain',
              display: { xs: 'none', sm: 'block' },
              boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
            }}
          />
          <Typography
            variant="h6"
            sx={{
              flexGrow: 1,
              fontWeight: 600,
              fontSize: { xs: '0.9375rem', sm: '1.0625rem' },
              letterSpacing: '-0.02em',
            }}
          >
            Bệnh viện Minh An — HRM
          </Typography>
          <Stack
            direction="row"
            alignItems="center"
            spacing={{ xs: 0.5, sm: 0.75 }}
            sx={{ mr: { xs: 0, sm: 0.25 } }}
          >
            <IconButton
              color="inherit"
              aria-label="Thông báo"
              aria-haspopup="true"
              aria-expanded={Boolean(notifAnchor)}
              onClick={(e) => setNotifAnchor(e.currentTarget)}
              sx={{ color: 'inherit' }}
            >
              <Badge
                badgeContent={unread ?? 0}
                color="secondary"
                max={99}
                invisible={unread == null || unread === 0}
              >
                <NotificationsNoneIcon />
              </Badge>
            </IconButton>
            <NotificationPopover
              open={Boolean(notifAnchor)}
              anchorEl={notifAnchor}
              onClose={() => setNotifAnchor(null)}
              onCountsUpdated={refreshUnread}
            />
            <Tooltip
              title={
                <Stack component="span" spacing={0.25} sx={{ py: 0.25 }}>
                  <Typography variant="caption" sx={{ fontWeight: 700, display: 'block' }}>
                    {user?.fullName || user?.username || '—'}
                  </Typography>
                  <Typography variant="caption" sx={{ opacity: 0.92, display: 'block' }}>
                    @{user?.username} · {getRoleLabel(user?.role)}
                  </Typography>
                </Stack>
              }
              arrow
              enterTouchDelay={0}
            >
              <IconButton
                onClick={(e) => setUserMenuAnchor(e.currentTarget)}
                aria-label="Tài khoản"
                aria-controls={userMenuAnchor ? 'account-menu' : undefined}
                aria-haspopup="true"
                sx={{ p: 0.35 }}
              >
                <Avatar {...headerAvatar(user?.fullName || user?.username || '?')} />
              </IconButton>
            </Tooltip>
            <Menu
              id="account-menu"
              anchorEl={userMenuAnchor}
              open={Boolean(userMenuAnchor)}
              onClose={() => setUserMenuAnchor(null)}
              anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
              transformOrigin={{ vertical: 'top', horizontal: 'right' }}
              slotProps={{ paper: { sx: { mt: 1.25, minWidth: 200, borderRadius: 2 } } }}
            >
              <MenuItem
                component={Link}
                to="/profile"
                onClick={() => setUserMenuAnchor(null)}
              >
                <ListItemIcon>
                  <PersonOutlineIcon fontSize="small" />
                </ListItemIcon>
                Trang cá nhân
              </MenuItem>
              <Divider />
              <MenuItem
                onClick={() => {
                  setUserMenuAnchor(null);
                  logout();
                  nav('/login');
                }}
              >
                <ListItemIcon>
                  <LogoutIcon fontSize="small" />
                </ListItemIcon>
                Đăng xuất
              </MenuItem>
            </Menu>
          </Stack>
        </Toolbar>
      </AppBar>

      <Drawer
        variant={mobile ? 'temporary' : 'persistent'}
        open={open}
        onClose={() => setOpen(false)}
        sx={{
          width: drawerWidth,
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            width: drawerWidth,
            boxSizing: 'border-box',
            borderRight: 'none',
            ...(mobile
              ? {
                  top: 0,
                  height: '100%',
                }
              : {
                  top: toolbarOffset,
                  height: { xs: 'calc(100% - 56px)', sm: 'calc(100% - 64px)' },
                }),
          },
        }}
      >
        {drawer}
      </Drawer>

      <Box
        component="main"
        sx={{
          flexGrow: 1,
          mt: { xs: 7, sm: 8 },
          width: { md: `calc(100% - ${open ? drawerWidth : 0}px)` },
          minHeight: '100vh',
          bgcolor: 'background.default',
          backgroundImage: `radial-gradient(ellipse 100% 60% at 50% -15%, ${alpha(theme.palette.primary.main, 0.07)}, transparent 52%)`,
        }}
      >
        <Box
          sx={{
            maxWidth: APP_CONTENT_MAX_WIDTH_PX,
            mx: 'auto',
            width: '100%',
            px: { xs: 2, sm: 3 },
            py: { xs: 2.5, sm: 3.5 },
            pb: { xs: 4, sm: 5 },
          }}
        >
          <Outlet />
        </Box>
      </Box>
    </Box>
  );
}
