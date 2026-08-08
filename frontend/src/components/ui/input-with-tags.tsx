import React, { useEffect, useId, useRef, useState } from 'react'
import { cn } from '@/lib/utils'
import { ShadcnButton } from '@/components/ui/shadcn-button'
import { X, ChevronDown, ChevronUp, Loader2 } from 'lucide-react'
import { inputClass } from '@/components/ui/PageHeader'

export interface TagSuggestion {
  id: string
  label: string
}

interface TagProps {
  text: string
  onRemove: () => void
}

const Tag = ({ text, onRemove }: TagProps) => (
  <span
    className="flex w-full max-w-full items-center gap-1 rounded-lg border border-primary-200 bg-primary-50 px-2.5 py-1.5 text-sm text-primary-900"
    title={text}
  >
    <span className="min-w-0 flex-1 truncate">{text}</span>
    <ShadcnButton
      type="button"
      variant="ghost"
      size="icon"
      onClick={onRemove}
      className="h-6 w-6 shrink-0 rounded-full text-primary-700 hover:bg-primary-100"
      aria-label={`Remove ${text}`}
    >
      <X className="w-3.5 h-3.5" />
    </ShadcnButton>
  </span>
)

export interface InputWithTagsProps {
  placeholder?: string
  className?: string
  /** Max number of tags; omit for unlimited */
  limit?: number
  tags?: string[]
  onTagsChange?: (tags: string[]) => void
  suggestions?: TagSuggestion[]
  onSearch?: (query: string) => void
  loading?: boolean
  disabled?: boolean
  required?: boolean
  id?: string
  /** Min typed characters before search/dropdown (default 1) */
  minSearchLength?: number
  /** Max suggestions shown in dropdown (default 10) */
  suggestionLimit?: number
  /** When false, only items from suggestions can be added */
  allowFreeText?: boolean
  /** Tags shown before "Read more" (default 6) */
  tagsCollapsedLimit?: number
}

export function InputWithTags({
  placeholder,
  className,
  limit,
  tags: controlledTags,
  onTagsChange,
  suggestions = [],
  onSearch,
  loading = false,
  disabled = false,
  required = false,
  id,
  minSearchLength = 1,
  suggestionLimit = 10,
  allowFreeText = false,
  tagsCollapsedLimit = 6,
}: InputWithTagsProps) {
  const generatedId = useId()
  const inputId = id ?? generatedId
  const [internalTags, setInternalTags] = useState<string[]>([])
  const [inputValue, setInputValue] = useState('')
  const [open, setOpen] = useState(false)
  const [tagsExpanded, setTagsExpanded] = useState(false)
  const [highlightedIndex, setHighlightedIndex] = useState(-1)
  const containerRef = useRef<HTMLDivElement>(null)
  const listRef = useRef<HTMLUListElement>(null)

  const tags = controlledTags ?? internalTags
  const setTags = (next: string[]) => {
    if (onTagsChange) {
      onTagsChange(next)
      return
    }
    setInternalTags(next)
  }

  const atLimit = limit != null && limit > 0 && tags.length >= limit

  const addTag = (value: string) => {
    const trimmed = String(value ?? '').trim()
    if (!trimmed || atLimit || tags.includes(trimmed)) return
    setTags([trimmed, ...tags])
    setInputValue('')
    setOpen(true)
    setTagsExpanded(false)
  }

  const removeTag = (indexToRemove: number) => {
    setTags(tags.filter((_, index) => index !== indexToRemove))
  }

  const hiddenTagCount = Math.max(0, tags.length - tagsCollapsedLimit)
  const visibleTags = tagsExpanded ? tags : tags.slice(0, tagsCollapsedLimit)

  const filteredSuggestions = suggestions
    .filter((s) => s.label && !tags.includes(s.label))
    .slice(0, suggestionLimit)

  const searchReady = inputValue.trim().length >= minSearchLength
  const showDropdown = open && !atLimit
  const canNavigate =
    showDropdown && searchReady && !loading && filteredSuggestions.length > 0
  const dropdownHint = !searchReady
    ? minSearchLength === 0
      ? null
      : `Type at least ${minSearchLength} character${minSearchLength === 1 ? '' : 's'} to search`
    : null
  const filteredCount = filteredSuggestions.length

  const navigateHighlight = (direction: 1 | -1) => {
    if (atLimit || filteredSuggestions.length === 0) return
    setOpen(true)
    setHighlightedIndex((prev) => {
      if (prev < 0) return direction === 1 ? 0 : filteredSuggestions.length - 1
      const next = prev + direction
      if (next < 0) return filteredSuggestions.length - 1
      if (next >= filteredSuggestions.length) return 0
      return next
    })
  }

  const selectHighlighted = () => {
    const suggestion = filteredSuggestions[highlightedIndex]
    if (!suggestion) return false
    addTag(suggestion.label)
    setHighlightedIndex(-1)
    return true
  }

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      if (canNavigate) navigateHighlight(1)
      else setOpen(true)
      return
    }

    if (e.key === 'ArrowUp') {
      e.preventDefault()
      if (canNavigate) navigateHighlight(-1)
      return
    }

    if (e.key === 'Enter') {
      e.preventDefault()
      if (selectHighlighted()) return
      if (!inputValue.trim()) return
      const match = suggestions.find(
        (s) =>
          String(s.label ?? '').toLowerCase() === inputValue.trim().toLowerCase()
      )
      if (match) {
        addTag(match.label)
      } else if (allowFreeText) {
        addTag(inputValue.trim())
      }
      return
    }

    if (e.key === 'Escape') {
      setOpen(false)
      setHighlightedIndex(-1)
    }
  }

  useEffect(() => {
    if (!onSearch) return
    if (inputValue.trim().length < minSearchLength) {
      // Clear parent query when below threshold so lists don't stay stale.
      if (minSearchLength > 0 && inputValue.trim().length === 0) {
        onSearch('')
      }
      return
    }
    const timer = window.setTimeout(() => onSearch(inputValue.trim()), 250)
    return () => window.clearTimeout(timer)
  }, [inputValue, minSearchLength, onSearch])

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setOpen(false)
        setHighlightedIndex(-1)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  useEffect(() => {
    if (!canNavigate) {
      setHighlightedIndex((prev) => (prev === -1 ? prev : -1))
      return
    }
    setHighlightedIndex((prev) => {
      if (prev < 0) return 0
      if (prev >= filteredCount) return filteredCount - 1
      return prev
    })
  }, [canNavigate, filteredCount])

  useEffect(() => {
    if (highlightedIndex < 0 || !listRef.current) return
    const option = listRef.current.querySelector(`[data-option-index="${highlightedIndex}"]`)
    option?.scrollIntoView({ block: 'nearest' })
  }, [highlightedIndex, filteredSuggestions])

  return (
    <div ref={containerRef} className={cn('flex flex-col gap-2 w-full', className)}>
      <div className="relative">
        <input
          id={inputId}
          type="text"
          value={inputValue}
          onChange={(e) => {
            setInputValue(e.target.value)
            setOpen(true)
            setHighlightedIndex(-1)
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={handleKeyDown}
          placeholder={
            atLimit
              ? 'Maximum selections reached'
              : placeholder || 'Type to search item code or name...'
          }
          className={cn(inputClass, 'pr-16')}
          disabled={disabled || atLimit}
          required={required && tags.length === 0}
          autoComplete="off"
          role="combobox"
          aria-expanded={showDropdown}
          aria-controls={`${inputId}-listbox`}
          aria-autocomplete="list"
          aria-activedescendant={
            highlightedIndex >= 0 ? `${inputId}-option-${highlightedIndex}` : undefined
          }
        />
        <div className="absolute inset-y-0 right-1 flex items-center gap-0.5">
          {loading ? (
            <div className="pointer-events-none flex h-8 w-8 items-center justify-center text-gray-400">
              <Loader2 className="h-4 w-4 animate-spin" />
            </div>
          ) : (
            <>
              <button
                type="button"
                tabIndex={-1}
                disabled={disabled || atLimit || !canNavigate}
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => navigateHighlight(-1)}
                className="flex h-7 w-7 items-center justify-center rounded-md text-gray-400 hover:bg-gray-100 hover:text-gray-600 disabled:opacity-40 disabled:hover:bg-transparent"
                aria-label="Previous option"
              >
                <ChevronUp className="h-4 w-4" />
              </button>
              <button
                type="button"
                tabIndex={-1}
                disabled={disabled || atLimit}
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => {
                  setOpen(true)
                  if (canNavigate) navigateHighlight(1)
                }}
                className="flex h-7 w-7 items-center justify-center rounded-md text-gray-400 hover:bg-gray-100 hover:text-gray-600 disabled:opacity-40 disabled:hover:bg-transparent"
                aria-label="Next option"
              >
                <ChevronDown className="h-4 w-4" />
              </button>
            </>
          )}
        </div>

        {showDropdown && (
            <ul
              ref={listRef}
              id={`${inputId}-listbox`}
              role="listbox"
              className="absolute z-20 mt-1 max-h-56 w-full overflow-auto rounded-lg border border-gray-200 bg-white py-1 shadow-lg"
            >
              {dropdownHint ? (
                <li className="px-3 py-2 text-sm text-gray-500">{dropdownHint}</li>
              ) : loading && filteredSuggestions.length === 0 ? (
                <li className="px-3 py-2 text-sm text-gray-500">Searching...</li>
              ) : filteredSuggestions.length === 0 ? (
                <li className="px-3 py-2 text-sm text-gray-500">No items found</li>
              ) : (
                filteredSuggestions.map((suggestion, index) => (
                  <li
                    key={suggestion.id}
                    id={`${inputId}-option-${index}`}
                    role="option"
                    aria-selected={index === highlightedIndex}
                    data-option-index={index}
                    onMouseEnter={() => setHighlightedIndex(index)}
                  >
                    <button
                      type="button"
                      className={cn(
                        'w-full px-3 py-2 text-left text-sm focus:outline-none',
                        index === highlightedIndex
                          ? 'bg-primary-100 text-primary-900'
                          : 'hover:bg-primary-50'
                      )}
                      onMouseDown={(e) => e.preventDefault()}
                      onClick={() => addTag(suggestion.label)}
                    >
                      {suggestion.label}
                    </button>
                  </li>
                ))
              )}
            </ul>
        )}
      </div>

      {tags.length > 0 && (
        <div className="flex flex-col gap-2 w-full">
          <div className="grid grid-cols-3 gap-2">
            {visibleTags.map((tag, index) => (
              <Tag
                key={`${tag}-${index}`}
                text={tag}
                onRemove={() => removeTag(index)}
              />
            ))}
          </div>
          {hiddenTagCount > 0 && (
            <button
              type="button"
              onClick={() => setTagsExpanded((prev) => !prev)}
              className="self-start text-sm font-medium text-primary-600 hover:text-primary-700 hover:underline"
            >
              {tagsExpanded
                ? 'Show less'
                : `Read more (${hiddenTagCount} older item${hiddenTagCount === 1 ? '' : 's'})`}
            </button>
          )}
        </div>
      )}
    </div>
  )
}
