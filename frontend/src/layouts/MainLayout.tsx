import ApartmentIcon from '@mui/icons-material/Apartment';
import AssessmentIcon from '@mui/icons-material/Assessment';
import CampaignIcon from '@mui/icons-material/Campaign';
import DescriptionIcon from '@mui/icons-material/Description';
import EventNoteIcon from '@mui/icons-material/EventNote';
import KeyboardArrowDownRoundedIcon from '@mui/icons-material/KeyboardArrowDownRounded';
import GroupsIcon from '@mui/icons-material/Groups';
import LogoutIcon from '@mui/icons-material/Logout';
import MenuIcon from '@mui/icons-material/Menu';
import NotificationsNoneIcon from '@mui/icons-material/NotificationsNone';
import PaymentsIcon from '@mui/icons-material/Payments';
import PeopleIcon from '@mui/icons-material/People';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import DashboardIcon from '@mui/icons-material/SpaceDashboard';
import TableChartIcon from '@mui/icons-material/TableChart';
import WorkOutlineIcon from '@mui/icons-material/WorkOutline';
import {
  AppBar,
  Avatar,
  Badge,
  Box,
  Collapse,
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
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { NotificationPopover } from '../components/layout/NotificationPopover';
import { APP_CONTENT_MAX_WIDTH_PX } from '../constants/layout';
import { useAuth } from '../context/AuthContext';
import * as notificationService from '../services/notificationService';
import { getRoleLabel } from '../utils/roleLabels';

const drawerWidth = 256;
const LOGO_SRC = '/logo.png';

/** Khớp chiều cao Toolbar — Drawer bắt đầu ngay dưới AppBar, không cắt nội dung */
const toolbarOffset = { xs: '56px', sm: '64px' };

const ALL_STAFF = ['ADMIN', 'EMPLOYEE', 'HR', 'HEAD_DEPARTMENT', 'HEAD_NURSING'] as const;
const ADMIN_ONLY = ['ADMIN'] as const;
const ADMIN_HR = ['ADMIN', 'HR'] as const;

const EMPLOYEE_CATEGORY_PATHS = ['/employees/official', '/employees/trial', '/employees/terminated'] as const;

type NavLink = {
  kind: 'link';
  to: string;
  label: string;
  icon: ReactNode;
  roles: readonly string[];
};

type NavSubMenu = {
  kind: 'submenu';
  id: string;
  label: string;
  icon: ReactNode;
  roles: readonly string[];
  children: NavLink[];
};

type NavGroupChild = NavLink | NavSubMenu;

type NavGroup = {
  id: string;
  label: string;
  icon: ReactNode;
  children: NavGroupChild[];
};

type NavEntry = { kind: 'link'; item: NavLink } | { kind: 'group'; group: NavGroup };

const NAV_ENTRIES: NavEntry[] = [
  {
    kind: 'link',
    item: { kind: 'link', to: '/', label: 'Dashboard', icon: <DashboardIcon fontSize="small" />, roles: ALL_STAFF },
  },
  {
    kind: 'link',
    item: {
      kind: 'link',
      to: '/announcements',
      label: 'Thông báo toàn viện',
      icon: <CampaignIcon fontSize="small" />,
      roles: ALL_STAFF,
    },
  },
  {
    kind: 'group',
    group: {
      id: 'org',
      label: 'Tổ chức',
      icon: <GroupsIcon fontSize="small" />,
      children: [
        { kind: 'link', to: '/departments', label: 'Phòng ban', icon: <ApartmentIcon fontSize="small" />, roles: ADMIN_ONLY },
        {
          kind: 'submenu',
          id: 'employees',
          label: 'Nhân viên',
          icon: <PeopleIcon fontSize="small" />,
          roles: ADMIN_HR,
          children: [
            { kind: 'link', to: '/employees/official', label: 'Chính thức', icon: <PeopleIcon fontSize="small" />, roles: ADMIN_HR },
            { kind: 'link', to: '/employees/trial', label: 'Thử việc / Thực tập', icon: <PeopleIcon fontSize="small" />, roles: ADMIN_HR },
            { kind: 'link', to: '/employees/terminated', label: 'Nghỉ việc', icon: <PeopleIcon fontSize="small" />, roles: ADMIN_HR },
          ],
        },
      ],
    },
  },
  {
    kind: 'group',
    group: {
      id: 'work',
      label: 'Công & đơn',
      icon: <WorkOutlineIcon fontSize="small" />,
      children: [
        { kind: 'link', to: '/work', label: 'Công', icon: <EventNoteIcon fontSize="small" />, roles: ALL_STAFF },
        { kind: 'link', to: '/requests', label: 'Đơn', icon: <DescriptionIcon fontSize="small" />, roles: ALL_STAFF },
        {
          kind: 'link',
          to: '/evaluations',
          label: 'Đánh giá & xếp loại',
          icon: <AssessmentIcon fontSize="small" />,
          roles: ALL_STAFF,
        },
      ],
    },
  },
  {
    kind: 'group',
    group: {
      id: 'salary',
      label: 'Lương',
      icon: <PaymentsIcon fontSize="small" />,
      children: [
        { kind: 'link', to: '/salary', label: 'Bảng lương', icon: <PaymentsIcon fontSize="small" />, roles: ALL_STAFF },
        {
          kind: 'link',
          to: '/salary-scales',
          label: 'Thang bảng lương',
          icon: <TableChartIcon fontSize="small" />,
          roles: ALL_STAFF,
        },
      ],
    },
  },
];

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

function pathActive(pathname: string, path: string): boolean {
  if (path === '/') return pathname === '/';
  if ((EMPLOYEE_CATEGORY_PATHS as readonly string[]).includes(path)) {
    return pathname === path;
  }
  return pathname === path || pathname.startsWith(`${path}/`);
}

function collectGroupLinks(children: NavGroupChild[]): NavLink[] {
  return children.flatMap((child) => (child.kind === 'link' ? [child] : child.children));
}

function groupHasActive(pathname: string, children: NavGroupChild[]): boolean {
  if (pathname.startsWith('/employees/') && children.some((c) => c.kind === 'submenu' && c.id === 'employees')) {
    return true;
  }
  return collectGroupLinks(children).some((c) => pathActive(pathname, c.to));
}

function submenuHasActive(pathname: string, submenu: NavSubMenu): boolean {
  if (submenu.id === 'employees' && pathname.startsWith('/employees/')) {
    return true;
  }
  return submenu.children.some((c) => pathActive(pathname, c.to));
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
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});

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

  const visibleEntries = useMemo(() => {
    if (!user) return [];
    return NAV_ENTRIES.map((entry) => {
      if (entry.kind === 'link') {
        return (entry.item.roles as readonly string[]).includes(user.role) ? entry : null;
      }
      const children = entry.group.children
        .map((child) => {
          if (child.kind === 'link') {
            return (child.roles as readonly string[]).includes(user.role) ? child : null;
          }
          if (!(child.roles as readonly string[]).includes(user.role)) {
            return null;
          }
          const subs = child.children.filter((c) => (c.roles as readonly string[]).includes(user.role));
          if (subs.length === 0) return null;
          return { ...child, children: subs };
        })
        .filter((c): c is NavGroupChild => c != null);
      if (children.length === 0) return null;
      return { kind: 'group' as const, group: { ...entry.group, children } };
    }).filter((e): e is NavEntry => e != null);
  }, [user]);

  // Tự mở nhóm chứa trang đang xem
  useEffect(() => {
    setExpanded((prev) => {
      const next = { ...prev };
      for (const entry of visibleEntries) {
        if (entry.kind === 'group' && groupHasActive(loc.pathname, entry.group.children)) {
          next[entry.group.id] = true;
        }
        if (entry.kind === 'group') {
          for (const child of entry.group.children) {
            if (child.kind === 'submenu' && submenuHasActive(loc.pathname, child)) {
              next[child.id] = true;
            }
          }
        }
      }
      return next;
    });
  }, [loc.pathname, visibleEntries]);

  function toggleGroup(id: string) {
    setExpanded((prev) => ({ ...prev, [id]: !prev[id] }));
  }

  const navLabel = {
    fontSize: '0.84rem',
    letterSpacing: '-0.015em',
    fontWeight: 600,
    fontWeightActive: 700,
  } as const;

  const navColor = (active: boolean) =>
    active ? theme.palette.primary.dark : theme.palette.text.primary;

  const navIconColor = (active: boolean) =>
    active ? theme.palette.primary.main : alpha(theme.palette.text.primary, 0.72);

  /** Reset theme ListItemButton margins so drawer owns its own spacing. */
  const navBtnBase = {
    m: 0,
    mx: 0,
    my: 0,
    borderRadius: 2,
    borderLeft: 'none',
    paddingLeft: undefined,
    '&.Mui-selected': {
      borderLeft: 'none',
      paddingLeft: undefined,
    },
  } as const;

  const topLinkSx = (active: boolean) => ({
    ...navBtnBase,
    mx: 1.25,
    mb: 0.4,
    px: 1.25,
    py: 0.9,
    minHeight: 40,
    color: navColor(active),
    bgcolor: active ? alpha(theme.palette.primary.main, 0.1) : 'transparent',
    boxShadow: active ? `inset 3px 0 0 ${theme.palette.primary.main}` : 'none',
    transition: 'background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease',
    '&:hover': {
      bgcolor: active ? alpha(theme.palette.primary.main, 0.14) : alpha(theme.palette.primary.main, 0.05),
    },
    '&.Mui-selected': {
      ...navBtnBase['&.Mui-selected'],
      bgcolor: alpha(theme.palette.primary.main, 0.1),
      color: theme.palette.primary.dark,
      boxShadow: `inset 3px 0 0 ${theme.palette.primary.main}`,
      '&:hover': { bgcolor: alpha(theme.palette.primary.main, 0.14) },
    },
  });

  const groupHeaderSx = () => ({
    ...navBtnBase,
    mx: 1.25,
    mb: 0.25,
    px: 1.25,
    py: 0.75,
    minHeight: 40,
    color: theme.palette.text.primary,
    bgcolor: 'transparent',
    '&:hover': {
      bgcolor: alpha(theme.palette.primary.main, 0.05),
    },
  });

  const childLinkSx = (active: boolean) => ({
    ...navBtnBase,
    mx: 1.25,
    mb: 0.3,
    ml: 1.25,
    pl: 1.1,
    pr: 1.1,
    py: 0.65,
    minHeight: 40,
    color: navColor(active),
    bgcolor: active ? alpha(theme.palette.primary.main, 0.1) : 'transparent',
    boxShadow: active ? `inset 3px 0 0 ${theme.palette.primary.main}` : 'none',
    transition: 'background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease',
    '&:hover': {
      bgcolor: active ? alpha(theme.palette.primary.main, 0.14) : alpha(theme.palette.primary.main, 0.05),
    },
    '&.Mui-selected': {
      ...navBtnBase['&.Mui-selected'],
      bgcolor: alpha(theme.palette.primary.main, 0.1),
      color: theme.palette.primary.dark,
      boxShadow: `inset 3px 0 0 ${theme.palette.primary.main}`,
      '&:hover': { bgcolor: alpha(theme.palette.primary.main, 0.14) },
    },
  });

  const grandchildLinkSx = (active: boolean) => ({
    ...navBtnBase,
    mx: 1.25,
    mb: 0.25,
    ml: 1.25,
    pl: 2.25,
    pr: 1.1,
    py: 0.55,
    minHeight: 36,
    color: navColor(active),
    bgcolor: active ? alpha(theme.palette.primary.main, 0.1) : 'transparent',
    boxShadow: active ? `inset 3px 0 0 ${theme.palette.primary.main}` : 'none',
    transition: 'background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease',
    '&:hover': {
      bgcolor: active ? alpha(theme.palette.primary.main, 0.14) : alpha(theme.palette.primary.main, 0.05),
    },
    '&.Mui-selected': {
      ...navBtnBase['&.Mui-selected'],
      bgcolor: alpha(theme.palette.primary.main, 0.1),
      color: theme.palette.primary.dark,
      boxShadow: `inset 3px 0 0 ${theme.palette.primary.main}`,
      '&:hover': { bgcolor: alpha(theme.palette.primary.main, 0.14) },
    },
  });

  const submenuHeaderSx = (hasActive: boolean) => ({
    ...navBtnBase,
    mx: 1.25,
    mb: 0.15,
    ml: 1.25,
    pl: 1.1,
    pr: 1.1,
    py: 0.6,
    minHeight: 38,
    color: hasActive ? theme.palette.primary.dark : theme.palette.text.primary,
    bgcolor: hasActive ? alpha(theme.palette.primary.main, 0.06) : 'transparent',
    '&:hover': {
      bgcolor: alpha(theme.palette.primary.main, 0.05),
    },
  });

  const drawer = (
    <Box
      sx={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        bgcolor: '#f7faf9',
        backgroundImage: `linear-gradient(180deg, ${alpha(theme.palette.primary.main, 0.06)} 0%, #f7faf9 120px)`,
      }}
    >
      <Box sx={{ px: 2, pt: 2, pb: 1.75 }}>
        <Stack direction="row" alignItems="center" spacing={1.25}>
          <Box
            component="img"
            src={LOGO_SRC}
            alt=""
            sx={{
              width: 38,
              height: 38,
              borderRadius: '10px',
              bgcolor: '#fff',
              p: 0.4,
              objectFit: 'contain',
              border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
              boxShadow: `0 4px 12px ${alpha(theme.palette.primary.main, 0.12)}`,
            }}
          />
          <Box sx={{ minWidth: 0 }}>
            <Typography
              sx={{
                fontWeight: 700,
                fontSize: '0.92rem',
                letterSpacing: '-0.03em',
                lineHeight: 1.2,
                color: theme.palette.primary.dark,
              }}
            >
              Bệnh Viện Minh An
            </Typography>
            <Typography
              sx={{
                display: 'block',
                mt: 0.2,
                fontSize: '0.68rem',
                fontWeight: 600,
                letterSpacing: '0.06em',
                textTransform: 'uppercase',
                color: theme.palette.text.secondary,
              }}
            >
              Quản trị nhân sự
            </Typography>
          </Box>
        </Stack>
      </Box>

      <Divider sx={{ mx: 1.75, borderColor: alpha(theme.palette.primary.main, 0.1) }} />

      <List
        sx={{
          flex: 1,
          py: 1.5,
          px: 0,
          minHeight: 0,
          overflowY: 'auto',
          '&::-webkit-scrollbar': { width: 4 },
          '&::-webkit-scrollbar-thumb': {
            bgcolor: alpha(theme.palette.primary.main, 0.2),
            borderRadius: 4,
          },
        }}
        disablePadding
      >
        {visibleEntries.map((entry, index) => {
          if (entry.kind === 'link') {
            const item = entry.item;
            const active = pathActive(loc.pathname, item.to);
            return (
              <ListItemButton
                key={item.to}
                component={Link}
                to={item.to}
                selected={active}
                onClick={() => mobile && setOpen(false)}
                sx={topLinkSx(active)}
              >
                <ListItemIcon
                  sx={{
                    minWidth: 34,
                    color: navIconColor(active),
                    '& .MuiSvgIcon-root': { fontSize: 20 },
                  }}
                >
                  {item.icon}
                </ListItemIcon>
                <ListItemText
                  primary={item.label}
                  primaryTypographyProps={{
                    fontWeight: active ? navLabel.fontWeightActive : navLabel.fontWeight,
                    fontSize: navLabel.fontSize,
                    letterSpacing: navLabel.letterSpacing,
                    noWrap: true,
                  }}
                />
              </ListItemButton>
            );
          }

          const { group } = entry;
          const isOpen = Boolean(expanded[group.id]);
          const hasActive = groupHasActive(loc.pathname, group.children);
          const showSectionGap = index > 0;

          return (
            <Box key={group.id} sx={{ mt: showSectionGap ? 1.25 : 0.5, mb: 0.25 }}>
              <ListItemButton
                onClick={() => toggleGroup(group.id)}
                sx={groupHeaderSx()}
                disableRipple
              >
                <ListItemIcon
                  sx={{
                    minWidth: 34,
                    color: navIconColor(hasActive),
                    '& .MuiSvgIcon-root': { fontSize: 20 },
                  }}
                >
                  {group.icon}
                </ListItemIcon>
                <ListItemText
                  primary={group.label}
                  primaryTypographyProps={{
                    fontWeight: hasActive ? navLabel.fontWeightActive : navLabel.fontWeight,
                    fontSize: navLabel.fontSize,
                    letterSpacing: navLabel.letterSpacing,
                    color: 'inherit',
                  }}
                />
                <Box
                  sx={{
                    width: 22,
                    height: 22,
                    borderRadius: 1.25,
                    display: 'grid',
                    placeItems: 'center',
                    color: alpha(theme.palette.text.primary, 0.55),
                    bgcolor: alpha(theme.palette.primary.main, isOpen || hasActive ? 0.08 : 0.04),
                    transition: 'transform 0.2s ease',
                    transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)',
                  }}
                >
                  <KeyboardArrowDownRoundedIcon sx={{ fontSize: 18 }} />
                </Box>
              </ListItemButton>

              <Collapse in={isOpen} timeout={180} unmountOnExit>
                <Box
                  sx={{
                    position: 'relative',
                    ml: 2.75,
                    pl: 0.5,
                    '&::before': {
                      content: '""',
                      position: 'absolute',
                      left: 0,
                      top: 4,
                      bottom: 4,
                      width: 2,
                      borderRadius: 1,
                      bgcolor: alpha(theme.palette.primary.main, 0.12),
                    },
                  }}
                >
                  <List disablePadding sx={{ py: 0.25 }}>
                    {group.children.map((child) => {
                      if (child.kind === 'submenu') {
                        const subOpen = Boolean(expanded[child.id]);
                        const subActive = submenuHasActive(loc.pathname, child);
                        return (
                          <Box key={child.id} sx={{ mb: 0.15 }}>
                            <ListItemButton
                              onClick={() => toggleGroup(child.id)}
                              sx={submenuHeaderSx(subActive)}
                              disableRipple
                            >
                              <ListItemIcon
                                sx={{
                                  minWidth: 34,
                                  color: navIconColor(subActive),
                                  '& .MuiSvgIcon-root': { fontSize: 20 },
                                }}
                              >
                                {child.icon}
                              </ListItemIcon>
                              <ListItemText
                                primary={child.label}
                                primaryTypographyProps={{
                                  fontWeight: subActive ? navLabel.fontWeightActive : navLabel.fontWeight,
                                  fontSize: navLabel.fontSize,
                                  letterSpacing: navLabel.letterSpacing,
                                  color: 'inherit',
                                }}
                              />
                              <Box
                                sx={{
                                  width: 20,
                                  height: 20,
                                  borderRadius: 1,
                                  display: 'grid',
                                  placeItems: 'center',
                                  color: alpha(theme.palette.text.primary, 0.5),
                                  transition: 'transform 0.2s ease',
                                  transform: subOpen ? 'rotate(180deg)' : 'rotate(0deg)',
                                }}
                              >
                                <KeyboardArrowDownRoundedIcon sx={{ fontSize: 16 }} />
                              </Box>
                            </ListItemButton>
                            <Collapse in={subOpen} timeout={160} unmountOnExit>
                              <List disablePadding sx={{ pb: 0.25 }}>
                                {child.children.map((grandchild) => {
                                  const active = pathActive(loc.pathname, grandchild.to);
                                  return (
                                    <ListItemButton
                                      key={grandchild.to}
                                      component={Link}
                                      to={grandchild.to}
                                      selected={active}
                                      onClick={() => mobile && setOpen(false)}
                                      sx={grandchildLinkSx(active)}
                                    >
                                      <ListItemText
                                        primary={grandchild.label}
                                        primaryTypographyProps={{
                                          fontWeight: active ? navLabel.fontWeightActive : 500,
                                          fontSize: '0.8rem',
                                          letterSpacing: navLabel.letterSpacing,
                                          noWrap: true,
                                        }}
                                      />
                                    </ListItemButton>
                                  );
                                })}
                              </List>
                            </Collapse>
                          </Box>
                        );
                      }

                      const active = pathActive(loc.pathname, child.to);
                      return (
                        <ListItemButton
                          key={child.to}
                          component={Link}
                          to={child.to}
                          selected={active}
                          onClick={() => mobile && setOpen(false)}
                          sx={childLinkSx(active)}
                        >
                          <ListItemIcon
                            sx={{
                              minWidth: 34,
                              color: navIconColor(active),
                              '& .MuiSvgIcon-root': { fontSize: 20 },
                            }}
                          >
                            {child.icon}
                          </ListItemIcon>
                          <ListItemText
                            primary={child.label}
                            primaryTypographyProps={{
                              fontWeight: active ? navLabel.fontWeightActive : navLabel.fontWeight,
                              fontSize: navLabel.fontSize,
                              letterSpacing: navLabel.letterSpacing,
                              noWrap: true,
                            }}
                          />
                        </ListItemButton>
                      );
                    })}
                  </List>
                </Box>
              </Collapse>
            </Box>
          );
        })}
      </List>

      <Box sx={{ px: 1.25, pb: 1.25, pt: 0.5 }}>
        <Divider sx={{ mb: 1, borderColor: alpha(theme.palette.primary.main, 0.1) }} />
        <ListItemButton
          onClick={() => {
            logout();
            nav('/login');
          }}
          sx={{
            ...navBtnBase,
            px: 1.25,
            py: 0.85,
            minHeight: 40,
            color: theme.palette.text.primary,
            '&:hover': {
              bgcolor: alpha('#c62828', 0.06),
              color: '#c62828',
            },
          }}
        >
          <ListItemIcon
            sx={{
              minWidth: 34,
              color: 'inherit',
              '& .MuiSvgIcon-root': { fontSize: 20 },
            }}
          >
            <LogoutIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText
            primary="Đăng xuất"
            primaryTypographyProps={{
              fontWeight: navLabel.fontWeight,
              fontSize: navLabel.fontSize,
              letterSpacing: navLabel.letterSpacing,
            }}
          />
        </ListItemButton>
      </Box>
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
              <MenuItem component={Link} to="/profile" onClick={() => setUserMenuAnchor(null)}>
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
            borderRight: `1px solid ${alpha(theme.palette.primary.main, 0.08)}`,
            boxShadow: mobile ? `8px 0 28px ${alpha('#0f172a', 0.12)}` : 'none',
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
