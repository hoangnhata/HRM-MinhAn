import { useSearchParams } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { AnnouncementBoard } from '../components/AnnouncementBoard';

export default function AnnouncementsPage() {
  const { user } = useAuth();
  const [searchParams] = useSearchParams();
  const announcementParam = searchParams.get('announcement');
  const focusAnnouncementId =
    announcementParam && /^\d+$/.test(announcementParam)
      ? Number.parseInt(announcementParam, 10)
      : null;
  const isAdmin = user?.role === 'ADMIN';
  return <AnnouncementBoard isAdmin={isAdmin} focusAnnouncementId={focusAnnouncementId} />;
}
