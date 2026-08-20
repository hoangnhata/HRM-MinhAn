import AccessTimeRoundedIcon from '@mui/icons-material/AccessTimeRounded';
import AutoAwesomeRoundedIcon from '@mui/icons-material/AutoAwesomeRounded';
import CheckRoundedIcon from '@mui/icons-material/CheckRounded';
import CloseFullscreenRoundedIcon from '@mui/icons-material/CloseFullscreenRounded';
import CloseRoundedIcon from '@mui/icons-material/CloseRounded';
import ContentCopyRoundedIcon from '@mui/icons-material/ContentCopyRounded';
import DescriptionOutlinedIcon from '@mui/icons-material/DescriptionOutlined';
import HelpOutlineRoundedIcon from '@mui/icons-material/HelpOutlineRounded';
import OpenInFullRoundedIcon from '@mui/icons-material/OpenInFullRounded';
import PersonRoundedIcon from '@mui/icons-material/PersonRounded';
import RestartAltRoundedIcon from '@mui/icons-material/RestartAltRounded';
import SendRoundedIcon from '@mui/icons-material/SendRounded';
import SmartToyOutlinedIcon from '@mui/icons-material/SmartToyOutlined';
import WorkHistoryOutlinedIcon from '@mui/icons-material/WorkHistoryOutlined';
import {
  Alert,
  Avatar,
  Box,
  ButtonBase,
  Chip,
  CircularProgress,
  Fab,
  IconButton,
  Paper,
  Stack,
  TextField,
  Tooltip,
  Typography,
  useMediaQuery,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import axios from 'axios';
import { Fragment, useEffect, useMemo, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { askHrAssistant } from '../../services/hrAssistantService';

type Message = {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  createdAt: Date;
  error?: boolean;
  usedTools?: string[];
};

type SuggestionGroup = {
  title: string;
  description: string;
  icon: ReactNode;
  color: string;
  questions: string[];
};

const WELCOME_TEXT = 'Xin chào! Tôi là trợ lý HRM Minh An. Tôi có thể hướng dẫn sử dụng phần mềm và tra cứu dữ liệu được cấp quyền cho tài khoản của bạn.';

const SUGGESTION_GROUPS: SuggestionGroup[] = [
  {
    title: 'Công & chấm công',
    description: 'Kiểm tra ngày công, lượt chấm và nguyên nhân thiếu công',
    icon: <WorkHistoryOutlinedIcon />,
    color: '#00796b',
    questions: [
      'Tháng này tôi thiếu chấm công những ngày nào?',
      'Ngày 02/08/2026 tại sao tôi chưa được tính công?',
      'Tôi cần làm gì khi quên chấm công?',
    ],
  },
  {
    title: 'Phép & đơn từ',
    description: 'Xem phép còn lại và trạng thái các loại đơn',
    icon: <DescriptionOutlinedIcon />,
    color: '#1976d2',
    questions: [
      'Tôi còn bao nhiêu ngày phép?',
      'Tôi có đơn nghỉ phép nào đang chờ duyệt?',
      'Đơn điều động gần nhất của tôi đã được duyệt chưa?',
    ],
  },
  {
    title: 'Hướng dẫn HRM',
    description: 'Hướng dẫn thao tác đúng chức năng trên phần mềm',
    icon: <HelpOutlineRoundedIcon />,
    color: '#ed6c02',
    questions: [
      'Hướng dẫn tôi tạo đơn nghỉ phép',
      'Tôi xem thông tin lương của mình ở đâu?',
    ],
  },
];

const TOOL_LABELS: Record<string, string> = {
  get_leave_balance: 'Hạn mức phép',
  get_missing_attendance: 'Dữ liệu chấm công',
  explain_attendance_day: 'Chi tiết ngày công',
  get_attendance_machine_logs: 'Log máy chấm',
  get_latest_deployment_request: 'Đơn điều động',
  get_week_schedule: 'Lịch làm việc',
  get_pending_leave_requests: 'Đơn nghỉ phép',
  get_leave_policy: 'Quy định phép',
  get_forgot_punch_guidance: 'Hướng dẫn chấm công',
  get_usage_guidance: 'Hướng dẫn HRM',
};

function errorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const value = error.response?.data as { message?: string } | undefined;
    return value?.message || 'Không kết nối được với trợ lý. Vui lòng thử lại.';
  }
  return 'Có lỗi khi gửi câu hỏi. Vui lòng thử lại.';
}

function formatTime(value: Date) {
  return new Intl.DateTimeFormat('vi-VN', { hour: '2-digit', minute: '2-digit' }).format(value);
}

function inlineMarkdown(text: string): ReactNode[] {
  const parts = text.split(/(\*\*[^*]+\*\*|`[^`]+`)/g).filter(Boolean);
  return parts.map((part, index) => {
    if (part.startsWith('**') && part.endsWith('**')) {
      return <Box component="strong" key={index} sx={{ fontWeight: 750 }}>{part.slice(2, -2)}</Box>;
    }
    if (part.startsWith('`') && part.endsWith('`')) {
      return (
        <Box component="code" key={index} sx={{ px: 0.55, py: 0.15, borderRadius: 0.75, bgcolor: 'action.hover', fontSize: '0.82em' }}>
          {part.slice(1, -1)}
        </Box>
      );
    }
    return <Fragment key={index}>{part}</Fragment>;
  });
}

function AssistantRichText({ text }: { text: string }) {
  const normalizedText = text
    .replace(/\$\\rightarrow\$/g, '→')
    .replace(/\\rightarrow/g, '→')
    .replace(/\$\\to\$/g, '→')
    .replace(/\\to/g, '→')
    // Một số model sinh dòng bullet rỗng giữa các mục, khiến giao diện có chấm trống.
    .replace(/^\s*[-*•]\s*$/gm, '');
  const rawBlocks = normalizedText.replace(/\r\n/g, '\n').split('\n');
  const isListLine = (value: string) => /^\s*(?:[-*•]|\d+[.)])\s+\S/.test(value);
  const blocks = rawBlocks.filter((raw, index) => {
    if (raw.trim()) return true;
    let previous = index - 1;
    let next = index + 1;
    while (previous >= 0 && !rawBlocks[previous].trim()) previous -= 1;
    while (next < rawBlocks.length && !rawBlocks[next].trim()) next += 1;
    // Không tạo khoảng trắng riêng giữa các dòng thuộc cùng một danh sách.
    return !(
      previous >= 0
      && next < rawBlocks.length
      && isListLine(rawBlocks[previous])
      && isListLine(rawBlocks[next])
    );
  });
  return (
    <Stack spacing={0.72}>
      {blocks.map((raw, index) => {
        const line = raw.trim();
        if (!line) return <Box key={index} sx={{ height: 2 }} />;
        const heading = line.match(/^#{1,3}\s+(.+)$/);
        if (heading) {
          return (
            <Typography key={index} sx={{ mt: index ? 0.55 : 0, fontSize: '0.92rem', lineHeight: 1.4, fontWeight: 800, color: 'primary.dark' }}>
              {inlineMarkdown(heading[1])}
            </Typography>
          );
        }
        const numbered = line.match(/^(\d+)[.)]\s+(.+)$/);
        if (numbered) {
          return (
            <Stack key={index} direction="row" spacing={0.8} alignItems="flex-start">
              <Box sx={{ minWidth: 21, height: 21, mt: 0.05, borderRadius: '50%', display: 'grid', placeItems: 'center', bgcolor: 'primary.main', color: '#fff', fontSize: '0.68rem', fontWeight: 800 }}>
                {numbered[1]}
              </Box>
              <Typography sx={{ flex: 1, fontSize: '0.875rem', lineHeight: 1.58 }}>{inlineMarkdown(numbered[2])}</Typography>
            </Stack>
          );
        }
        const bullet = line.match(/^[-*•]\s+(.+)$/);
        if (bullet) {
          return (
            <Box
              key={index}
              sx={{
                display: 'grid',
                gridTemplateColumns: '8px minmax(0, 1fr)',
                columnGap: 0.75,
                alignItems: 'baseline',
                width: '100%',
              }}
            >
              <Typography
                component="span"
                aria-hidden="true"
                sx={{ color: 'primary.main', fontSize: '0.95rem', lineHeight: 1.58, fontWeight: 900 }}
              >
                •
              </Typography>
              <Typography sx={{ minWidth: 0, fontSize: '0.875rem', lineHeight: 1.58, overflowWrap: 'anywhere' }}>
                {inlineMarkdown(bullet[1])}
              </Typography>
            </Box>
          );
        }
        return <Typography key={index} sx={{ fontSize: '0.875rem', lineHeight: 1.62 }}>{inlineMarkdown(line)}</Typography>;
      })}
    </Stack>
  );
}

export function HrAssistantWidget() {
  const theme = useTheme();
  const mobile = useMediaQuery(theme.breakpoints.down('sm'));
  const [open, setOpen] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [activeGroup, setActiveGroup] = useState(0);
  const [messages, setMessages] = useState<Message[]>([
    { id: 'welcome', role: 'assistant', text: WELCOME_TEXT, createdAt: new Date() },
  ]);
  const endRef = useRef<HTMLDivElement | null>(null);
  const hasConversation = messages.some((message) => message.role === 'user');
  const activeSuggestions = useMemo(() => SUGGESTION_GROUPS[activeGroup], [activeGroup]);

  useEffect(() => {
    if (open) endRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, loading, open]);

  function resetConversation() {
    setMessages([{ id: 'welcome', role: 'assistant', text: WELCOME_TEXT, createdAt: new Date() }]);
    setInput('');
    setActiveGroup(0);
    setCopiedId(null);
  }

  async function copyAnswer(message: Message) {
    try {
      await navigator.clipboard.writeText(message.text);
      setCopiedId(message.id);
      window.setTimeout(() => setCopiedId((current) => (current === message.id ? null : current)), 1600);
    } catch {
      setCopiedId(null);
    }
  }

  async function submit(value?: string) {
    const question = (value ?? input).trim();
    if (!question || loading) return;
    setInput('');
    setMessages((prev) => [...prev, { id: crypto.randomUUID(), role: 'user', text: question, createdAt: new Date() }]);
    setLoading(true);
    try {
      const result = await askHrAssistant(question);
      setMessages((prev) => [
        ...prev,
        {
          id: result.requestId || crypto.randomUUID(),
          role: 'assistant',
          text: result.answer,
          createdAt: new Date(),
          usedTools: result.usedTools,
        },
      ]);
    } catch (error) {
      setMessages((prev) => [
        ...prev,
        { id: crypto.randomUUID(), role: 'assistant', text: errorMessage(error), createdAt: new Date(), error: true },
      ]);
    } finally {
      setLoading(false);
    }
  }

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    void submit();
  }

  return (
    <>
      {!open && (
        <Tooltip title="Trợ lý nhân sự AI" placement="left" arrow>
          <Fab
            color="primary"
            aria-label="Mở trợ lý nhân sự AI"
            onClick={() => setOpen(true)}
            sx={{
              position: 'fixed', right: { xs: 18, sm: 26 }, bottom: { xs: 18, sm: 26 }, zIndex: (t) => t.zIndex.speedDial,
              width: { xs: 56, sm: 60 }, height: { xs: 56, sm: 60 },
              backgroundImage: `linear-gradient(145deg, ${theme.palette.primary.main}, ${theme.palette.primary.dark})`,
              boxShadow: `0 12px 34px ${alpha(theme.palette.primary.dark, 0.4)}`,
              '&::after': { content: '""', position: 'absolute', inset: -5, border: `1px solid ${alpha(theme.palette.primary.main, 0.22)}`, borderRadius: '50%' },
            }}
          >
            <SmartToyOutlinedIcon />
          </Fab>
        </Tooltip>
      )}

      {open && (
        <Paper
          role="dialog"
          aria-label="Trợ lý nhân sự AI"
          elevation={20}
          sx={{
            position: 'fixed', zIndex: (t) => t.zIndex.modal, display: 'flex', flexDirection: 'column', overflow: 'hidden',
            transition: 'width 180ms ease, height 180ms ease',
            ...(mobile
              ? { inset: 0, borderRadius: 0 }
              : {
                  right: 24, bottom: 24,
                  width: expanded ? 'min(720px, calc(100vw - 48px))' : 480,
                  height: expanded ? 'min(820px, calc(100vh - 48px))' : 'min(740px, calc(100vh - 48px))',
                  borderRadius: 4,
                  border: `1px solid ${alpha(theme.palette.primary.main, 0.14)}`,
                  boxShadow: `0 24px 70px ${alpha('#0f172a', 0.24)}`,
                }),
          }}
        >
          <Box sx={{ px: { xs: 1.5, sm: 2 }, py: 1.5, color: '#fff', backgroundImage: `linear-gradient(130deg, ${theme.palette.primary.dark}, ${theme.palette.primary.main} 72%, #15968e)` }}>
            <Stack direction="row" alignItems="center" spacing={1.25}>
              <Avatar sx={{ bgcolor: 'rgba(255,255,255,0.15)', border: '1px solid rgba(255,255,255,0.22)', width: 42, height: 42 }}>
                <SmartToyOutlinedIcon />
              </Avatar>
              <Box sx={{ minWidth: 0, flex: 1 }}>
                <Stack direction="row" alignItems="center" spacing={0.75}>
                  <Typography sx={{ fontWeight: 800, lineHeight: 1.25 }}>Trợ lý HRM Minh An</Typography>
                  <Box sx={{ width: 7, height: 7, borderRadius: '50%', bgcolor: '#7CFFB2', boxShadow: '0 0 0 3px rgba(124,255,178,0.14)' }} />
                </Stack>
                <Typography variant="caption" sx={{ color: 'rgba(255,255,255,0.82)' }}>Tra cứu an toàn · Theo đúng quyền tài khoản</Typography>
              </Box>
              {hasConversation && (
                <Tooltip title="Cuộc trò chuyện mới">
                  <IconButton color="inherit" onClick={resetConversation} aria-label="Làm mới cuộc trò chuyện"><RestartAltRoundedIcon /></IconButton>
                </Tooltip>
              )}
              {!mobile && (
                <Tooltip title={expanded ? 'Thu nhỏ' : 'Mở rộng'}>
                  <IconButton color="inherit" onClick={() => setExpanded((value) => !value)} aria-label={expanded ? 'Thu nhỏ cửa sổ' : 'Mở rộng cửa sổ'}>
                    {expanded ? <CloseFullscreenRoundedIcon /> : <OpenInFullRoundedIcon />}
                  </IconButton>
                </Tooltip>
              )}
              <IconButton color="inherit" onClick={() => setOpen(false)} aria-label="Đóng trợ lý"><CloseRoundedIcon /></IconButton>
            </Stack>
          </Box>

          <Alert severity="info" icon={<AutoAwesomeRoundedIcon fontSize="small" />} sx={{ borderRadius: 0, py: 0.4, px: 1.5, '& .MuiAlert-message': { py: 0.35 }, '& .MuiAlert-icon': { py: 0.35, mr: 0.8 } }}>
            <Typography variant="caption">Chỉ hỗ trợ chức năng, dữ liệu và quy định đang áp dụng trên HRM Minh An.</Typography>
          </Alert>

          <Box sx={{ flex: 1, minHeight: 0, overflowY: 'auto', px: { xs: 1.25, sm: 1.75 }, py: 1.7, bgcolor: '#f4f8f8', scrollbarColor: `${alpha(theme.palette.primary.main, 0.25)} transparent` }}>
            <Stack spacing={1.45}>
              {messages.map((message) => {
                const user = message.role === 'user';
                return (
                  <Stack key={message.id} direction={user ? 'row-reverse' : 'row'} spacing={0.8} alignItems="flex-end">
                    <Avatar sx={{ width: 30, height: 30, bgcolor: user ? 'grey.600' : 'primary.main', flexShrink: 0, boxShadow: '0 2px 8px rgba(15,23,42,0.12)' }}>
                      {user ? <PersonRoundedIcon sx={{ fontSize: 17 }} /> : <SmartToyOutlinedIcon sx={{ fontSize: 17 }} />}
                    </Avatar>
                    <Box sx={{ maxWidth: user ? '82%' : { xs: '86%', sm: expanded ? '88%' : '84%' }, minWidth: 0 }}>
                      <Paper
                        elevation={0}
                        sx={{
                          px: user ? 1.4 : 1.55, py: user ? 1 : 1.25,
                          borderRadius: user ? '16px 16px 4px 16px' : '16px 16px 16px 4px',
                          bgcolor: user ? 'primary.main' : '#fff', color: user ? '#fff' : message.error ? 'error.dark' : 'text.primary',
                          border: user ? 'none' : `1px solid ${alpha(message.error ? '#d32f2f' : theme.palette.primary.main, 0.13)}`,
                          boxShadow: user ? `0 5px 14px ${alpha(theme.palette.primary.main, 0.18)}` : '0 3px 14px rgba(15,23,42,0.055)',
                        }}
                      >
                        {user
                          ? <Typography sx={{ fontSize: '0.875rem', lineHeight: 1.55, whiteSpace: 'pre-wrap' }}>{message.text}</Typography>
                          : <AssistantRichText text={message.text} />}
                      </Paper>
                      <Stack direction="row" alignItems="center" justifyContent={user ? 'flex-end' : 'space-between'} spacing={1} sx={{ mt: 0.45, px: 0.3 }}>
                        <Stack direction="row" spacing={0.45} alignItems="center" sx={{ minWidth: 0, overflow: 'hidden' }}>
                          <AccessTimeRoundedIcon sx={{ fontSize: 12, color: 'text.disabled' }} />
                          <Typography variant="caption" color="text.disabled" sx={{ fontSize: '0.65rem' }}>{formatTime(message.createdAt)}</Typography>
                          {!user && message.usedTools?.slice(0, 2).map((tool) => (
                            <Chip key={tool} label={TOOL_LABELS[tool] || 'Dữ liệu HRM'} size="small" variant="outlined" sx={{ height: 19, fontSize: '0.61rem', bgcolor: alpha(theme.palette.primary.main, 0.03), '& .MuiChip-label': { px: 0.65 } }} />
                          ))}
                        </Stack>
                        {!user && hasConversation && !message.error && (
                          <Tooltip title={copiedId === message.id ? 'Đã sao chép' : 'Sao chép câu trả lời'}>
                            <IconButton size="small" onClick={() => void copyAnswer(message)} aria-label="Sao chép câu trả lời" sx={{ width: 25, height: 25, color: copiedId === message.id ? 'success.main' : 'text.disabled' }}>
                              {copiedId === message.id ? <CheckRoundedIcon sx={{ fontSize: 15 }} /> : <ContentCopyRoundedIcon sx={{ fontSize: 14 }} />}
                            </IconButton>
                          </Tooltip>
                        )}
                      </Stack>
                    </Box>
                  </Stack>
                );
              })}

              {!hasConversation && (
                <Box sx={{ pt: 0.4 }}>
                  <Typography sx={{ mb: 1, fontSize: '0.78rem', fontWeight: 750, color: 'text.secondary' }}>Bạn muốn hỏi về nội dung nào?</Typography>
                  <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr 1fr', sm: expanded ? 'repeat(4, 1fr)' : '1fr 1fr' }, gap: 0.75 }}>
                    {SUGGESTION_GROUPS.map((group, index) => (
                      <ButtonBase key={group.title} onClick={() => setActiveGroup(index)} sx={{ p: 1, justifyContent: 'flex-start', textAlign: 'left', borderRadius: 2.25, border: `1px solid ${index === activeGroup ? alpha(group.color, 0.42) : alpha('#64748b', 0.14)}`, bgcolor: index === activeGroup ? alpha(group.color, 0.075) : '#fff' }}>
                        <Stack direction="row" spacing={0.85} alignItems="center">
                          <Box sx={{ width: 29, height: 29, borderRadius: 1.5, display: 'grid', placeItems: 'center', color: group.color, bgcolor: alpha(group.color, 0.1), '& .MuiSvgIcon-root': { fontSize: 17 } }}>{group.icon}</Box>
                          <Typography sx={{ fontSize: '0.72rem', lineHeight: 1.3, fontWeight: 700 }}>{group.title}</Typography>
                        </Stack>
                      </ButtonBase>
                    ))}
                  </Box>
                  <Paper variant="outlined" sx={{ mt: 0.85, p: 1.1, borderRadius: 2.5, bgcolor: '#fff', borderColor: alpha(activeSuggestions.color, 0.18) }}>
                    <Typography sx={{ mb: 0.75, fontSize: '0.69rem', color: 'text.secondary' }}>{activeSuggestions.description}</Typography>
                    <Stack spacing={0.55}>
                      {activeSuggestions.questions.map((question) => (
                        <ButtonBase key={question} onClick={() => void submit(question)} sx={{ px: 1, py: 0.7, justifyContent: 'flex-start', textAlign: 'left', borderRadius: 1.6, bgcolor: alpha(activeSuggestions.color, 0.045), color: 'text.primary', '&:hover': { bgcolor: alpha(activeSuggestions.color, 0.09) } }}>
                          <Typography sx={{ fontSize: '0.76rem', lineHeight: 1.4 }}>{question}</Typography>
                        </ButtonBase>
                      ))}
                    </Stack>
                  </Paper>
                </Box>
              )}

              {loading && (
                <Stack direction="row" spacing={0.8} alignItems="center">
                  <Avatar sx={{ width: 30, height: 30, bgcolor: 'primary.main' }}><SmartToyOutlinedIcon sx={{ fontSize: 17 }} /></Avatar>
                  <Paper variant="outlined" sx={{ px: 1.4, py: 1, borderRadius: '16px 16px 16px 4px', bgcolor: '#fff' }}>
                    <Stack direction="row" spacing={1} alignItems="center"><CircularProgress size={15} /><Typography variant="caption" color="text.secondary">Đang kiểm tra dữ liệu HRM…</Typography></Stack>
                  </Paper>
                </Stack>
              )}
              <div ref={endRef} />
            </Stack>
          </Box>

          {hasConversation && (
            <Stack direction="row" spacing={0.65} sx={{ px: 1.45, pt: 0.9, overflowX: 'auto', bgcolor: '#fff', borderTop: `1px solid ${alpha('#64748b', 0.09)}`, '&::-webkit-scrollbar': { display: 'none' } }}>
              {['Tôi còn bao nhiêu ngày phép?', 'Đơn nào đang chờ duyệt?', 'Hướng dẫn quên chấm công'].map((question) => (
                <Chip key={question} label={question} size="small" variant="outlined" onClick={() => void submit(question)} disabled={loading} sx={{ flexShrink: 0, height: 27, fontSize: '0.68rem' }} />
              ))}
            </Stack>
          )}

          <Box component="form" onSubmit={onSubmit} sx={{ px: { xs: 1.25, sm: 1.5 }, pt: 1, pb: { xs: 1.15, sm: 1.3 }, bgcolor: '#fff' }}>
            <Stack direction="row" spacing={0.8} alignItems="flex-end">
              <TextField
                fullWidth multiline maxRows={4} value={input} onChange={(event) => setInput(event.target.value)}
                onKeyDown={(event) => { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); void submit(); } }}
                placeholder="Hỏi về công, phép, đơn từ hoặc cách dùng HRM…" disabled={loading}
                inputProps={{ maxLength: 2000, 'aria-label': 'Câu hỏi cho trợ lý nhân sự' }}
                sx={{ '& .MuiOutlinedInput-root': { borderRadius: 3, pr: 1, fontSize: '0.875rem', bgcolor: '#fbfdfd', '&.Mui-focused': { bgcolor: '#fff' } } }}
              />
              <IconButton type="submit" disabled={!input.trim() || loading} aria-label="Gửi câu hỏi" sx={{ width: 45, height: 45, color: '#fff', bgcolor: input.trim() && !loading ? 'primary.main' : 'action.disabledBackground', boxShadow: input.trim() && !loading ? `0 6px 16px ${alpha(theme.palette.primary.main, 0.25)}` : 'none', '&:hover': { bgcolor: 'primary.dark' } }}>
                <SendRoundedIcon sx={{ fontSize: 21 }} />
              </IconButton>
            </Stack>
            <Stack direction="row" justifyContent="space-between" sx={{ mt: 0.55, px: 0.45 }}>
              <Typography variant="caption" color="text.disabled" sx={{ fontSize: '0.63rem' }}>Chỉ trả lời nội dung thuộc HRM Minh An</Typography>
              <Typography variant="caption" color="text.disabled" sx={{ fontSize: '0.63rem' }}>{input.length}/2000</Typography>
            </Stack>
          </Box>
        </Paper>
      )}
    </>
  );
}
