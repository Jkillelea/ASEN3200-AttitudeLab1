function out = escape(in_str)
  escape_symbols = '_';

  out = ''; % output string

  for i = 1:length(in_str)
    char = in_str(i);

    if any(char == escape_symbols)
      out = strcat(out, '\', char);
    else
      out = strcat(out, char);
    end
  end
end
