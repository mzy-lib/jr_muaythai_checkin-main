import { Sword } from 'lucide-react';

interface Props {
  className?: string;
}

export const MartialArtsIcon = ({ className = "w-12 h-12 mx-auto mb-4" }: Props) => (
  <Sword className={`${className} rotate-45`} />
);