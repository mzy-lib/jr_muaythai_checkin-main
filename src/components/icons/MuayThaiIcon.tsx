interface Props {
  className?: string;
}

export const MuayThaiIcon = ({ className = "w-24 h-24 mx-auto mb-4" }: Props) => (
  <img 
    src="/jr-logo.webp" 
    alt="JR Muay Thai Logo" 
    className={className}
  />
);