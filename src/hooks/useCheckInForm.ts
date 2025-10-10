import { useState } from 'react';
import { CheckInFormData } from '../types/database';
import { validateCheckInForm } from '../utils/validation/formValidation';
import { messages } from '../utils/messageUtils';

interface UseCheckInFormResult {
  formData: CheckInFormData;
  error: string;
  loading: boolean;
  needsEmailVerification: boolean;
  handleFieldChange: (field: string, value: string) => void;
  handleSubmit: (e: React.FormEvent) => Promise<void>;
  handleEmailVerification: (email: string) => Promise<void>;
  resetEmailVerification: () => void;
}

export function useCheckInForm(
  onSubmit: (data: CheckInFormData) => Promise<void>
): UseCheckInFormResult {
  const [formData, setFormData] = useState<CheckInFormData>({
    name: '',
    email: '',
    classType: 'morning'
  });
  const [needsEmailVerification, setNeedsEmailVerification] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleFieldChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    setError('');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    const validation = validateCheckInForm(formData.name, formData.email, needsEmailVerification);
    if (!validation.isValid) {
      setError(validation.error || messages.checkIn.error);
      return;
    }

    setError('');
    setLoading(true);

    try {
      await onSubmit(formData);
    } catch (err) {
      if (err instanceof Error && err.message.includes('duplicate_name')) {
        setNeedsEmailVerification(true);
      } else {
        setError(err instanceof Error ? err.message : messages.checkIn.error);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleEmailVerification = async (email: string) => {
    setFormData(prev => ({ ...prev, email }));
    await onSubmit({ ...formData, email });
  };

  const resetEmailVerification = () => {
    setNeedsEmailVerification(false);
    setFormData(prev => ({ ...prev, email: '' }));
  };

  return {
    formData,
    error,
    loading,
    needsEmailVerification,
    handleFieldChange,
    handleSubmit,
    handleEmailVerification,
    resetEmailVerification
  };
}