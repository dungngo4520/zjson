pub const Error = error{
    // Parse errors
    UnexpectedEnd,
    InvalidSyntax,
    InvalidEscape,
    InvalidNumber,
    TrailingCharacters,
    MaxDepthExceeded,
    DocumentTooLarge,
    DuplicateKey,
    // Conversion errors
    NumberOverflow,
    TypeError,
    IndexOutOfBounds,
    // Query errors
    InvalidPath,
    KeyNotFound,
    // Memory
    OutOfMemory,
};
