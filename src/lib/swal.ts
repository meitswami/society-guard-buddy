import Swal from 'sweetalert2';

// Get current theme for SWAL styling (exported for other Swal.fire calls)
export const getSwalThemeColors = () => {
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  return {
    background: isDark ? '#1a1a2e' : '#ffffff',
    color: isDark ? '#e2e8f0' : '#1a1a2e',
    confirmButtonColor: 'hsl(142, 71%, 45%)',
    cancelButtonColor: '#6b7280',
  };
};

export const confirmAction = async (
  title: string,
  text: string,
  confirmText: string = 'Yes',
  cancelText: string = 'No',
): Promise<boolean> => {
  const theme = getSwalThemeColors();
  const result = await Swal.fire({
    title,
    text,
    icon: 'warning',
    showCancelButton: true,
    confirmButtonText: confirmText,
    cancelButtonText: cancelText,
    background: theme.background,
    color: theme.color,
    confirmButtonColor: theme.confirmButtonColor,
    cancelButtonColor: theme.cancelButtonColor,
    customClass: {
      popup: 'rounded-2xl',
    },
  });
  return result.isConfirmed;
};

export const showSuccess = (title: string, text: string) => {
  const theme = getSwalThemeColors();
  Swal.fire({
    title,
    text,
    icon: 'success',
    timer: 1500,
    showConfirmButton: false,
    background: theme.background,
    color: theme.color,
    customClass: {
      popup: 'rounded-2xl',
    },
  });
};

export const showToast = (title: string) => {
  const theme = getSwalThemeColors();
  const Toast = Swal.mixin({
    toast: true,
    position: 'top',
    showConfirmButton: false,
    timer: 2500,
    timerProgressBar: true,
    background: theme.background,
    color: theme.color,
  });
  Toast.fire({ icon: 'success', title });
};
