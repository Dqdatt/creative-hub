import { Bell, Download, Share, SquarePlus, WifiOff, Zap } from 'lucide-react';
import type { ReactNode } from 'react';
import logo from '../../assets/logo.png';
import { useToast } from '../common/toastContext';
import { promptInstall, rememberInstallDismissed } from '../../pwa/pwa';
import type { InstallPlatform } from '../../pwa/pwa';
import { BottomSheet } from './BottomSheet';

interface InstallSheetProps {
  open: boolean;
  platform: InstallPlatform;
  onClose: () => void;
}

function Step({ n, children }: { n: number; children: ReactNode }) {
  return (
    <li className="m-install-step">
      <span className="m-install-step-n">{n}</span>
      <span>{children}</span>
    </li>
  );
}

export function InstallSheet({ open, platform, onClose }: InstallSheetProps) {
  const { showToast } = useToast();

  const dismiss = () => {
    rememberInstallDismissed();
    onClose();
  };

  const install = async () => {
    const outcome = await promptInstall();
    if (outcome === 'accepted') {
      onClose();
      return;
    }
    if (outcome === 'dismissed') {
      dismiss();
      return;
    }
    showToast({ type: 'info', message: 'Trình duyệt này chưa hỗ trợ cài trực tiếp. Hãy mở bằng Chrome hoặc Safari.' });
  };

  const footer = platform === 'prompt' ? (
    <>
      <button type="button" className="m-btn m-btn--ghost" onClick={dismiss}>Để sau</button>
      <button type="button" className="m-btn" onClick={() => void install()}>
        <Download aria-hidden="true" /> Cài đặt
      </button>
    </>
  ) : (
    <button type="button" className="m-btn m-btn--ghost m-btn--block" onClick={dismiss}>Đã hiểu</button>
  );

  return (
    <BottomSheet open={open} title="Cài CreativeHub" onClose={dismiss} footer={footer}>
      <div className="m-install-head">
        <img src={logo} alt="" className="m-install-logo" />
        <p>Dùng CreativeHub như một app trên điện thoại.</p>
      </div>
      <ul className="m-install-benefits">
        <li><Zap aria-hidden="true" /><span><b>Mở nhanh từ màn hình chính</b>Toàn màn hình, không có thanh địa chỉ.</span></li>
        <li><Bell aria-hidden="true" /><span><b>Cập nhật theo thời gian thực</b>Task mới, lịch quay, thông báo hiện ngay khi mở app.</span></li>
        <li><WifiOff aria-hidden="true" /><span><b>Vẫn mở được khi mạng yếu</b>Giao diện đã lưu sẵn trên máy.</span></li>
      </ul>
      {platform === 'ios-safari' ? (
        <ol className="m-install-steps" aria-label="Cách cài trên iPhone">
          <Step n={1}>Bấm <span className="m-key"><Share aria-hidden="true" />Chia sẻ</span> ở thanh dưới của Safari</Step>
          <Step n={2}>Chọn <span className="m-key"><SquarePlus aria-hidden="true" />Thêm vào MH chính</span></Step>
          <Step n={3}>Bấm <b>Thêm</b> ở góc trên bên phải</Step>
        </ol>
      ) : null}
      {platform === 'ios-other' ? (
        <p className="m-install-note">Trên iPhone, hãy mở trang này bằng <b>Safari</b> rồi chọn Chia sẻ → Thêm vào MH chính.</p>
      ) : null}
      {platform === 'unsupported' ? (
        <p className="m-install-note">Mở trang này bằng <b>Chrome</b> trên Android hoặc <b>Safari</b> trên iPhone để cài app.</p>
      ) : null}
    </BottomSheet>
  );
}
